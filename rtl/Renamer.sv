import riscv_constants_pkg::*;
import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_decoder_types_pkg::*;
import riscv_renamer_types_pkg::*;
import riscv_rob_types_pkg::*;

module RegisterRenamer (
    input logic clk,
    input logic reset,
    input decoder_output_t decoder_out,
    input flush_t flush_info,
    output rat_output_t rat_out,
    ReorderBuffer_if.Renamer_Side rob_bus,
    Writeback_if.Renamer_Side wb_bus,
    Commit_if.Renamer_Side commit_bus
);

  /// Speculative Register Alias Table
  physical_reg_t [31:0] RAT;

  /// Architectual Register Alias Table
  (* maybe_unused *)
  physical_reg_t [31:0] ARAT;

  /// The `free_list` tracks which physical registers are free (1) vs allocated (0). 
  /// Free registers can be used as destination registers for new instructions.
  free_list_t free_list;

  /// Combinational logic for the next free list state.
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

  typedef struct packed {
    logic valid;
    physical_reg_t idx;
  } next_free_t;

  // Could be replaced with always_comb
  function automatic next_free_t get_next_free(free_list_t fl);
    next_free_t result;

    result.valid = 0;
    result.idx   = P0;

    for (int i = 1; i < NUM_PHYSICAL_REGS; i++) begin
      if (fl[i] && !result.valid) begin
        result.valid = 1;
        result.idx   = physical_reg_t'(i);
      end
    end

    return result;
  endfunction

  function automatic free_list_t get_freed_list;
    free_list_t freed_list = '0;

    for (int i = 0; i < COMMIT_WIDTH; i++) begin
      if (commit_bus.committed_rob_entries[i].valid &&
        commit_bus.committed_rob_entries[i].old_dest != P0) begin

        if (commit_bus.committed_rob_entries[i].has_rd && commit_bus.committed_rob_entries[i].new_dest != P0) begin
          assert (ARAT[commit_bus.committed_rob_entries[i].rd] == commit_bus.committed_rob_entries[i].old_dest)
          else
            $error(
                "Commit mismatch: ARAT[%0d]=P%0d but ROB old_dest=P%0d",
                commit_bus.committed_rob_entries[i].rd,
                ARAT[commit_bus.committed_rob_entries[i].rd],
                commit_bus.committed_rob_entries[i].old_dest
            );
        end

        freed_list[commit_bus.committed_rob_entries[i].old_dest] = 1'b1;
      end
    end

    return freed_list;
  endfunction

  logical_reg_t rs1, rs2;
  uop_t uop;
  assign uop = decoder_out.uop;

  // Extract source register indices from decoded uop
  always_comb begin
    if (!uop.has_rs1) rs1 = x0;
    else rs1 = uop.rs1;
    if (!uop.has_rs2) rs2 = x0;
    else rs2 = uop.rs2;
  end

  /// Obtain the next free physical register from the free list. This is used for renaming
  /// destination registers of new instructions.
  next_free_t next_free;
  assign next_free = get_next_free(free_list);

  always_comb begin
    free_list_next = free_list;

    if (decoder_out.valid && !flush_info.valid) begin
      // Free committed regs
      free_list_next |= get_freed_list();

      // Allocate new reg
      if (uop.has_rd && uop.rd != x0 && next_free.valid) begin
        free_list_next[next_free.idx] = 1'b0;
      end
    end

    // Flush override (highest priority)
    if (flush_info.valid) begin
      free_list_next = checkpoints[flush_info.rob_idx].free_list;
    end
  end

  // Update free list on clock edge.
  always_ff @(posedge clk) begin
    if (reset) begin
      free_list <= {NUM_PHYSICAL_REGS{1'b1}};

      // Mark architectural regs as allocated
      for (int i = 0; i < 32; i++) begin
        free_list[i] <= 1'b0;
      end

    end else begin
      free_list <= free_list_next;
    end
  end

  logic ps1_ready_now;
  logic ps2_ready_now;

  always_comb begin
    ps1_ready_now = !uop.has_rs1 || !busy_list[RAT[rs1]];
    ps2_ready_now = !uop.has_rs2 || !busy_list[RAT[rs2]];

    if (wb_bus.alu_writeback.valid) begin
      if (uop.has_rs1 && RAT[rs1] == wb_bus.alu_writeback.pdst) ps1_ready_now = 1'b1;
      if (uop.has_rs2 && RAT[rs2] == wb_bus.alu_writeback.pdst) ps2_ready_now = 1'b1;
    end

    if (wb_bus.mem_writeback.valid) begin
      if (uop.has_rs1 && RAT[rs1] == wb_bus.mem_writeback.pdst) ps1_ready_now = 1'b1;
      if (uop.has_rs2 && RAT[rs2] == wb_bus.mem_writeback.pdst) ps2_ready_now = 1'b1;
    end
  end

  /// Next ROB index for checkpointing (the ROB index for this instruction is 
  /// allocated in the next stage)
  logic [ROB_IDX_WIDTH-1:0] next_rob_idx;
  assign next_rob_idx = rat_out.advance_pipeline ? rob_bus.next_tail_ptr : rob_bus.tail_ptr;

  always_ff @(posedge clk) begin

    assert (free_list_next[0] == 1'b0)
    else $error("Error: physical register P0 should never be allocated");

    if (reset) begin

      // Mark all ready
      busy_list <= '0;

      for (int i = 0; i < 32; i++) begin
        RAT[i] <= physical_reg_t'(i);
      end
    end else begin
      rat_out <= '0;
      busy_list_next = busy_list;

      for (int i = 0; i < 32; i++) begin
        assert (!free_list[RAT[i]])
        else $error("RAT[%0d] maps to free physical register P%0d", i, RAT[i]);
      end

      if (flush_info.valid) begin
        RAT <= checkpoints[flush_info.rob_idx].RAT;
        busy_list <= '0; // on recovery, mark all busy bits as 0 since we don't know which instructions were in-flight
      end else if (decoder_out.valid) begin
        rat_out.advance_pipeline <= 1'b1;

        // Read sources
        rat_out.Ps1 <= uop.has_rs1 ? RAT[rs1] : P0;
        rat_out.Ps2 <= uop.has_rs2 ? RAT[rs2] : P0;

        rat_out.Ps1_ready <= ps1_ready_now;
        rat_out.Ps2_ready <= ps2_ready_now;

        // Writeback results (mark destination registers as ready)
        if (wb_bus.alu_writeback.valid) begin
          busy_list[wb_bus.alu_writeback.pdst] <= 1'b0;
        end

        if (wb_bus.mem_writeback.valid) begin
          busy_list[wb_bus.mem_writeback.pdst] <= 1'b0;
        end

        if (uop.has_rd) begin
          if (uop.rd == x0) begin
            // x0 special case
            rat_out.Pd_old <= P0;
            rat_out.Pd_new <= P0;
          end else if (next_free.valid && next_free.idx != P0) begin
            rat_out.Pd_old <= RAT[uop.rd];
            rat_out.Pd_new <= next_free.idx;

            if (next_free.idx == RAT[uop.rd]) begin
              $display("BAD FREE LIST:");
              $display("  uop.rd=x%0d", uop.rd);
              $display("  RAT[x%0d]=P%0d", uop.rd, RAT[uop.rd]);
              $display("  next_free=P%0d", next_free.idx);
              $display("  free_list[RAT[x%0d]]=%0b", uop.rd, free_list[RAT[uop.rd]]);
              $display("  free_list_next[RAT[x%0d]]=%0b", uop.rd, free_list_next[RAT[uop.rd]]);

              for (int r = 0; r < 32; r++) begin
                if (RAT[r] == next_free.idx) begin
                  $display("  P%0d is currently mapped by RAT[x%0d]", next_free.idx, r);
                end
              end

              for (int c = 0; c < COMMIT_WIDTH; c++) begin
                if (commit_bus.committed_rob_entries[c].valid) begin
                  $display("  committing ROB PC=%0d rd=x%0d old=P%0d new=P%0d has_rd=%0b",
                           commit_bus.committed_rob_entries[c].PC,
                           commit_bus.committed_rob_entries[c].rd,
                           commit_bus.committed_rob_entries[c].old_dest,
                           commit_bus.committed_rob_entries[c].new_dest,
                           commit_bus.committed_rob_entries[c].has_rd);
                end
              end
            end

            assert (next_free.idx != RAT[uop.rd])
            else
              $error(
                  "Error: next free register is the same as the current mapping for destination register %0d",
                  uop.rd
              );

            RAT[uop.rd] <= next_free.idx;

            busy_list[next_free.idx] <= 1'b1;
          end else begin
            // no free physical register: stall rename/dispatch
            rat_out <= '0;
            // keep RAT unchanged
          end
        end else begin
          // no destination instruction
          rat_out.Pd_old <= P0;
          rat_out.Pd_new <= P0;
        end

        rat_out.uop <= uop;

        rat_out.stq_idx <= decoder_out.stq_idx;
        rat_out.ldq_idx <= decoder_out.ldq_idx;

        rat_out.rob_idx <= next_rob_idx;

      end
    end
  end

  // Commit (update ARAT and free physical registers)
  always_ff @(posedge clk) begin
    if (reset) begin
      // Initial architectural state: xN -> PN
      for (int i = 0; i < 32; i++) begin
        ARAT[i] <= physical_reg_t'(i);
      end
    end else begin
      // Update ARAT only on commit
      for (int i = 0; i < COMMIT_WIDTH; i++) begin
        if (commit_bus.committed_rob_entries[i].valid) begin
          automatic ROB_entry_t entry = commit_bus.committed_rob_entries[i];
          if (entry.new_dest != P0 && entry.has_rd) begin
            ARAT[entry.rd] <= entry.new_dest;
          end
        end
      end
    end
  end

  /// Create Checkpoint on branch instructions
  always_ff @(posedge clk) begin
    if (reset) begin
    end else begin
      if (decoder_out.valid) begin
        if (uop.is_branch) begin
          checkpoints[next_rob_idx].free_list <= free_list;
          checkpoints[next_rob_idx].valid <= 1'b1;
          checkpoints[next_rob_idx].RAT <= RAT;
        end
      end
    end
  end

endmodule : RegisterRenamer
