import riscv_constants_pkg::*;
// import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_decoder_types_pkg::*;
import riscv_renamer_types_pkg::*;
import riscv_rob_types_pkg::*;
import riscv_util_pkg::*;
import riscv_renamer_util_pkg::*;

`include "riscv/util.svh"

module RegisterRenamer (
    input logic clk,
    input logic reset,
    input decoder_output_t decoder_out,
    input flush_t flush_info,
    input logic dispatcher_fire,
    output logic renamer_fire,
    output logic rename_stall,

    /// Output buffer to the dispatcher. We must hold this valid until the dispatcher 
    /// accepts it, since the dispatcher needs to see the rename information in order
    /// to know what to push to the ROB and IQs.
    output rat_output_t rat_out,

    ReorderBuffer_if.Renamer_Side rob_bus,
    Writeback_if.Renamer_Side wb_bus,
    Commit_if.Renamer_Side commit_bus
);

  rat_output_t rat_out_next;

  /// Speculative Register Alias Table
  physical_reg_t [31:0] RAT;
  physical_reg_t [31:0] RAT_next;

  /// Architectual Register Alias Table
  (* maybe_unused *)
  physical_reg_t [31:0] ARAT;
  physical_reg_t [31:0] ARAT_next;

  /// The `free_list` tracks which physical registers are free (1) vs allocated (0). 
  /// Free registers can be used as destination registers for new instructions.
  free_list_t free_list;
  free_list_t free_list_next;

  /// The `busy_list` tracks which physical registers are ready (0) vs which 
  /// are waiting for an instruction to writeback to them (1). When all physical
  /// operands for an instruction are ready, we can issue it.
  // TODO: Forward writeback results into busy list next
  logic [NUM_PHYSICAL_REGS-1:0] busy_list;
  logic [NUM_PHYSICAL_REGS-1:0] busy_list_next;

  /// Checkpoints for branch instructions. Allows quickly restoring the RAT 
  /// and free list on a branch mispredict.
  /// TODO: Free checkpoints once no longer needed. 
  checkpoint_t checkpoints[ROB_WIDTH];

  /// Current `uop` from the decoder
  uop_t uop;
  assign uop = decoder_out.uop;

  /// Obtain the next free physical register from the free list. This is used for renaming
  /// destination registers of new instructions.
  next_free_t next_free;
  assign next_free = get_next_free(free_list);

  /// Means instruction needs a new physical destination, but none is available.
  wire free_list_stall = uop.has_rd && uop.rd != x0 && !next_free.valid;

  /// Whether the renamer is ready to accept a new instruction from the decoder. The renamer 
  /// needs to be ready in order for the decoder to advance and output a new instruction.
  /// The renamer is ready when:
  /// 1) We aren't currently flushing (we can't accept new instructions during a flush)
  /// 2) We have a free physical register to allocate for the destination register (if needed)
  /// 3) The dispatcher has accepted the instruction OR the output buffer is free
  wire renamer_ready = !flush_info.valid && !free_list_stall && (!rat_out.valid || dispatcher_fire);

  /// TODO: What happens if dispatcher isn't ready? 

  /// Whether we can accept the output of the decoder this cycle. Accepting the decoder output
  /// means we will overwrite the current `rat_out` with new rename information taken from the 
  /// decoder output. 
  assign renamer_fire = decoder_out.valid && renamer_ready;

  assign rename_stall = decoder_out.valid && !renamer_fire && !dispatcher_fire;

  /// Logical Source Register from the instruction
  logical_reg_t rs1, rs2;

  /// Physical source registers after looking up rs1 and rs2 in the RAT
  physical_reg_t Ps1, Ps2;

  // Is the physical source register for rs1/rs2 ready to be read/used?
  logic Ps1_ready, Ps2_ready;

  /// The physical register that used to hold `rd`
  physical_reg_t Pd_old;

  /// The new physical register allocated for `rd`
  physical_reg_t Pd_new;

  /// Next ROB index for checkpointing (the ROB index for this instruction is 
  /// allocated in the next stage)
  logic [ROB_IDX_WIDTH-1:0] next_rob_idx;
  assign next_rob_idx = rat_out.valid ? rob_bus.next_tail_ptr : rob_bus.tail_ptr;

  always_comb begin
    RAT_next = RAT;
    ARAT_next = ARAT;
    free_list_next = free_list;
    busy_list_next = busy_list;
    rat_out_next = '0;

    // ------------------------------------------------------------
    // Flush path
    // ------------------------------------------------------------
    // On a flush, we must restore the RAT and free list to the state they were in at 
    // the checkpoint corresponding to the ROB index we're flushing to. We can also 
    // ignore any writebacks in the current cycle
    // We also mark all younger checkpoints as invalid, since those correspond to instructions 
    // that are younger than the flush target, and thus should also be squashed by the flush.
    // This happens in the always_ff block below.
    if (flush_info.valid) begin
      RAT_next = checkpoints[flush_info.rob_idx].RAT;
      free_list_next = checkpoints[flush_info.rob_idx].free_list;
      busy_list_next = busy_list;
    end

    // ------------------------------------------------------------
    // Commit path
    // ------------------------------------------------------------
    // On commit, we can update the ARAT to reflect the committed architectural 
    // state of the register file. We can also free the old physical register 
    // that was mapped to the committed destination register.
    for (int i = 0; i < COMMIT_WIDTH; i++) begin
      ROB_entry_t entry;
      entry = commit_bus.committed_rob_entries[i];

      if (entry.valid && entry.has_rd && entry.rd != x0) begin
        ARAT_next[entry.rd] = entry.new_dest;

        if (entry.old_dest != P0) begin
          free_list_next[entry.old_dest] = 1'b1;
        end
      end
    end

    // ------------------------------------------------------------
    // Writeback path
    // ------------------------------------------------------------
    // On a writeback, the physical register being written back is now ready to be read/used by 
    // future instructions, so we can clear the corresponding bit in the busy list.
    if (!flush_info.valid) begin
      if (wb_bus.alu_writeback.valid && wb_bus.alu_writeback.pdst != P0) begin
        busy_list_next[wb_bus.alu_writeback.pdst] = 1'b0;
      end

      if (wb_bus.mem_writeback.valid && wb_bus.mem_writeback.pdst != P0) begin
        busy_list_next[wb_bus.mem_writeback.pdst] = 1'b0;
      end
    end

    // ------------------------------------------------------------
    // Rename path
    // ------------------------------------------------------------
    // On rename, we first set the physical source registers based on the RAT mappings.
    // Then we check to see if it has a destination register that needs to be renamed. 
    // If so, we allocate a new physical register from the free list.
    rat_out_next.valid = rat_out.valid && !dispatcher_fire;
    if (renamer_fire) begin
      rat_out_next.valid = 1'b1;

      rat_out_next.Ps1 = Ps1;
      rat_out_next.Ps2 = Ps2;

      rat_out_next.Ps1_ready = Ps1_ready;
      rat_out_next.Ps2_ready = Ps2_ready;

      rat_out_next.Pd_old = Pd_old;
      rat_out_next.Pd_new = Pd_new;

      rat_out_next.uop = uop;
      rat_out_next.uop.pdst = Pd_new;
      rat_out_next.uop.prs1 = Ps1;
      rat_out_next.uop.prs2 = Ps2;

      rat_out_next.stq_idx = decoder_out.stq_idx;
      rat_out_next.ldq_idx = decoder_out.ldq_idx;
      rat_out_next.rob_idx = next_rob_idx;

      if (uop.has_rd && uop.rd != x0) begin
        RAT_next[uop.rd] = Pd_new;
        free_list_next[Pd_new] = 1'b0;
        busy_list_next[Pd_new] = 1'b1;
      end
    end

    if (renamer_fire) begin

    end
  end

  always_comb begin

    rs1 = uop.has_rs1 ? uop.rs1 : x0;
    rs2 = uop.has_rs2 ? uop.rs2 : x0;

    Ps1 = uop.has_rs1 ? RAT[rs1] : P0;
    Ps2 = uop.has_rs2 ? RAT[rs2] : P0;

    Ps1_ready = !uop.has_rs1 || !busy_list[Ps1];
    Ps2_ready = !uop.has_rs2 || !busy_list[Ps2];

    // same-cycle ALU writeback bypass
    if (wb_bus.alu_writeback.valid) begin
      if (uop.has_rs1 && Ps1 == wb_bus.alu_writeback.pdst) Ps1_ready = 1'b1;

      if (uop.has_rs2 && Ps2 == wb_bus.alu_writeback.pdst) Ps2_ready = 1'b1;
    end

    // same-cycle memory writeback bypass
    if (wb_bus.mem_writeback.valid) begin
      if (uop.has_rs1 && Ps1 == wb_bus.mem_writeback.pdst) Ps1_ready = 1'b1;

      if (uop.has_rs2 && Ps2 == wb_bus.mem_writeback.pdst) Ps2_ready = 1'b1;
    end

    Pd_old = P0;
    Pd_new = P0;

    if (renamer_fire && uop.has_rd && uop.rd != x0) begin
      Pd_old = RAT[uop.rd];
      Pd_new = next_free.idx;
    end
  end

  // ------------------------------------------------------------
  // Latch Next State
  // ------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (reset) begin
      rat_out   <= '0;

      free_list <= {NUM_PHYSICAL_REGS{1'b1}};
      busy_list <= '0;

      for (int i = 0; i < 32; i++) begin
        RAT[i] <= physical_reg_t'(i);
        ARAT[i] <= physical_reg_t'(i);
        free_list[i] <= 1'b0;
      end

      free_list[P0] <= 1'b0;
    end else begin
      RAT <= RAT_next;
      ARAT <= ARAT_next;
      free_list <= free_list_next;
      busy_list <= busy_list_next;
      rat_out <= rat_out_next;
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      for (int i = 0; i < ROB_WIDTH; i++) begin
        checkpoints[i].valid <= 1'b0;
      end
    end else if (flush_info.valid) begin
      // Invalidate the checkpoint we used and all younger checkpoints.
      // Keep older checkpoints, because older unresolved branches may still need recovery.
      for (int k = 0; k < ROB_WIDTH; k++) begin
        if (checkpoints[k].valid) begin
          if (k[ROB_IDX_WIDTH-1:0] == flush_info.rob_idx || is_younger(
                  k[ROB_IDX_WIDTH-1:0], flush_info.rob_idx, rob_bus.head_ptr
              )) begin
            checkpoints[k].valid <= 1'b0;
          end
        end
      end
    end else begin

      // On commit we must update all existing valid checkpoints to free any 
      // physical registers that are being freed by the commit. This is necessary 
      // to ensure that if we later flush to one of those checkpoints, we don't end up 
      // with a free list that incorrectly marks a free physical register as still in use.
      for (int c = 0; c < COMMIT_WIDTH; c++) begin
        ROB_entry_t entry;
        entry = commit_bus.committed_rob_entries[c];

        if (entry.valid && entry.has_rd && entry.rd != x0 && entry.old_dest != P0) begin
          for (int k = 0; k < ROB_WIDTH; k++) begin
            if (checkpoints[k].valid) begin
              checkpoints[k].free_list[entry.old_dest] <= 1'b1;
            end
          end
        end
      end

      // Invalidate checkpoint for committed branch/jump.
      for (int c = 0; c < COMMIT_WIDTH; c++) begin
        ROB_entry_t entry;
        entry = commit_bus.committed_rob_entries[c];

        if (entry.valid && entry.is_branch) begin
          checkpoints[entry.rob_idx].valid <= 1'b0;
        end
      end

      // If its a branch or jump instruction, then we store a checkpoint so we can return 
      // to this state if the branch is mispredicted. 
      if (renamer_fire && (uop.is_branch || uop.is_jump)) begin
        checkpoints[next_rob_idx].valid <= 1'b1;
        checkpoints[next_rob_idx].RAT <= RAT_next;
        checkpoints[next_rob_idx].free_list <= free_list_next;
      end
    end
  end

  // ------------------------------------------------------------
  // Verification Assertions
  // ------------------------------------------------------------
  // This module has been very problematic--so these AI generated assertions help catch bugs early.

  // Assertions to check invariants on RAT and free list
  always_ff @(posedge clk) begin
    if (!reset) begin
      `RV_ASSERT(!free_list[P0], ("P0 appeared on free list"))

      `RV_ASSERT(!free_list_next[P0], ("P0 appeared on free_list_next"))

      for (int r = 0; r < 32; r++) begin
        `RV_ASSERT(!free_list[RAT[r]],
                   ("Current RAT maps x%0d to free physical register P%0d", r, RAT[r]))
      end
    end
  end

  // Decode holds during rename stall
  always_ff @(posedge clk) begin
    if (!reset && !flush_info.valid) begin
      if ($past(decoder_out.valid && rename_stall && !flush_info.valid)) begin
        `RV_ASSERT(decoder_out.valid,
                   ("Decoder dropped valid instruction during rename stall. old_pc=%0d", $past
                   (decoder_out.uop.pc)))

        `RV_ASSERT(decoder_out.uop.pc == $past(decoder_out.uop.pc),
                   ("Decoder PC changed during rename stall: old_pc=%0d new_pc=%0d", $past
                   (decoder_out.uop.pc), decoder_out.uop.pc))
      end
    end
  end

  // No two architectural registers alias the same physical register except x0/P0
  always_comb begin
    for (int r = 0; r < 32; r++) begin
      for (int s = r + 1; s < 32; s++) begin
        `RV_ASSERT(!(RAT[r] != P0 && RAT[r] == RAT[s]),
                   ("RAT alias: x%0d and x%0d both map to P%0d", r, s, RAT[r]))
      end
    end
  end

  // Flush must restore a usable free list
  always_ff @(posedge clk) begin
    if (!reset && flush_info.valid) begin
      `RV_ASSERT(checkpoints[flush_info.rob_idx].valid,
                 ("Flush to invalid checkpoint: rob_idx=%0d", flush_info.rob_idx))

      `RV_ASSERT(!checkpoints[flush_info.rob_idx].free_list[P0],
                 ("Checkpoint free list has P0 free: rob_idx=%0d", flush_info.rob_idx))

      for (int r = 0; r < 32; r++) begin
        `RV_ASSERT(
            !checkpoints[flush_info.rob_idx].free_list[checkpoints[flush_info.rob_idx].RAT[r]],
            ("Checkpoint would free live RAT mapping: rob=%0d x%0d -> P%0d",
        flush_info.rob_idx,
        r,
        checkpoints[flush_info.rob_idx].RAT[r]))
      end
    end
  end

  always_comb begin
    for (int i = 0; i < COMMIT_WIDTH; i++) begin
      ROB_entry_t entry;
      entry = commit_bus.committed_rob_entries[i];

      if (entry.valid && entry.has_rd && entry.rd != x0 && entry.old_dest != P0) begin
        for (int r = 0; r < 32; r++) begin
          `RV_ASSERT(RAT[r] != entry.old_dest,
                     ("Commit wants to free P%0d from rd=x%0d, but RAT[x%0d] still maps to it",
        entry.old_dest, entry.rd, r)
    )
        end
      end
    end
  end

  always_comb begin
    physical_reg_t [31:0] arat_walk;
    arat_walk = ARAT;

    for (int i = 0; i < COMMIT_WIDTH; i++) begin
      ROB_entry_t entry;
      entry = commit_bus.committed_rob_entries[i];

      if (entry.valid && entry.has_rd && entry.rd != x0) begin
        if (entry.old_dest != P0) begin
          `RV_ASSERT(
              arat_walk[entry.rd] == entry.old_dest,
              ("Commit mismatch: entry=%0d rd=x%0d expected old=P%0d actual old=P%0d new=P%0d", i, entry.rd, arat_walk[entry.rd], entry.old_dest, entry.new_dest))
        end

        arat_walk[entry.rd] = entry.new_dest;
      end
    end
  end

  always_comb begin
    if (flush_info.valid) begin
      for (int r = 0; r < 32; r++) begin
        `RV_ASSERT(!free_list_next[RAT_next[r]],
                   ("Flush recovery would make RAT[x%0d]=P%0d free", r, RAT_next[r]))
      end
    end
  end

  always_comb begin
    if (rat_out.valid) begin
      `RV_ASSERT(
          rat_out.Pd_new == rat_out.uop.pdst,
          ("Renamer out is not consistent with uop: expected Pd_new=P%0d got Pd_new=P%0d", rat_out.uop.pdst, rat_out.Pd_new))
    end
  end

endmodule : RegisterRenamer
