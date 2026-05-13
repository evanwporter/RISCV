import riscv_rob_types_pkg::*;
import riscv_constants_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_util_pkg::*;

`include "riscv/util.svh"

module ReorderBuffer (
    input logic clk,
    input logic reset,

    input flush_t flush_info,

    input  branch_info_t branch_info,
    output branch_info_t oldest_branch_info,

    ReorderBuffer_if.ROB_Side bus,
    Commit_if.ROB_Side commit_bus,
    Writeback_if.Renamer_Side wb_bus,

    Syscall_if.ReorderBuffer_Side su_bus
);

  // initial begin
  //   `RV_ASSERT((ROB_WIDTH <= 1) || ((ROB_WIDTH & (ROB_WIDTH - 1)) != 0),
  //              ("ROB_WIDTH must be a power of two. Got ROB_WIDTH=%0d", ROB_WIDTH))
  // end

  // TODO: make it a circular buffer by tracking the count

  ROB_entry_t entries[ROB_WIDTH];

  logic [ROB_IDX_WIDTH-1:0] head, tail;

  assign bus.head_entry = entries[head];
  assign bus.head_ptr = head;
  assign bus.tail_ptr = tail;
  assign bus.next_tail_ptr = bus.full ? tail : tail + 1;

  logic [ROB_IDX_WIDTH-1:0] next_tail;
  assign next_tail = tail + 1;

  assign bus.full  = (next_tail == head);

  function automatic logic survives_flush(input logic [ROB_IDX_WIDTH-1:0] entry_idx);
    return !is_younger(entry_idx, flush_info.rob_idx, head);
  endfunction

  // ------------------------------------------------------------
  // Find Oldest Unresolved Branch
  // ------------------------------------------------------------
  always_comb begin
    oldest_branch_info = '0;

    for (int unsigned off = 0; off < ROB_WIDTH; off++) begin
      logic [ROB_IDX_WIDTH-1:0] idx;
      idx = head + ROB_IDX_WIDTH'(off);

      if (entries[idx].valid &&
        entries[idx].is_branch &&
        !entries[idx].branch_info.flushed &&
        !entries[idx].branch_info.resolved) begin
        oldest_branch_info = entries[idx].branch_info;
        break;
      end
    end
  end

  always_ff @(posedge clk) begin
    logic [ROB_IDX_WIDTH-1:0] idx;

    /// TODO replace i w/ commit_count
    logic [4:0] commit_count;
    commit_count = 0;

    if (reset) begin
      head <= '0;
      tail <= '0;

      for (int i = 0; i < ROB_WIDTH; i++) begin
        entries[i] <= '0;
      end

    end else

    // ------------------------------------------------------------
    // Flush
    // ------------------------------------------------------------
    if (flush_info.valid) begin
      // Preserve completions for older/surviving instructions.
      if (bus.ALU_executed_op.executed_op_valid && survives_flush(
              bus.ALU_executed_op.executed_op_rob_idx
          )) begin
        entries[bus.ALU_executed_op.executed_op_rob_idx].busy <= 1'b0;
      end

      if (bus.STR_executed_op.executed_op_valid && survives_flush(
              bus.STR_executed_op.executed_op_rob_idx
          )) begin
        entries[bus.STR_executed_op.executed_op_rob_idx].busy <= 1'b0;
      end

      // Invalidate younger entries
      for (int i = 0; i < ROB_WIDTH; i++) begin
        if (entries[i].valid) begin
          if (is_younger(i[ROB_IDX_WIDTH-1:0], flush_info.rob_idx, head)) begin
            entries[i].valid <= 1'b0;
            entries[i] <= '0;  // not technically necessary, but makes debugging easier
          end
        end
      end

      // Rewind tail to just after branch
      tail <= flush_info.rob_idx + 1;

      // Stop commit this cycle
      for (int i = 0; i < COMMIT_WIDTH; i++) begin
        commit_bus.committed_rob_entries[i] <= '0;
      end

      entries[flush_info.rob_idx].branch_info.flushed  <= 1'b1;
      entries[flush_info.rob_idx].branch_info.resolved <= 1'b1;

    end else begin

      if (branch_info.valid) begin
        entries[branch_info.rob_idx].branch_info <= branch_info;
        entries[branch_info.rob_idx].branch_info.resolved <= !branch_info.mispredict;
        // entries[branch_info.rob_idx].branch_info.flushed <= 1'b1;
      end

      if (bus.ALU_executed_op.executed_op_valid) begin
        entries[bus.ALU_executed_op.executed_op_rob_idx].busy <= 1'b0;
      end

      if (bus.STR_executed_op.executed_op_valid) begin
        entries[bus.STR_executed_op.executed_op_rob_idx].busy <= 1'b0;
      end

      // ------------------------------------------------------------
      // Commit
      // ------------------------------------------------------------

      // Clear commit bus before we start filling it with committed entries
      // This is necessary because in the below loop we may break early.
      for (int i = 0; i < COMMIT_WIDTH; i++) begin
        commit_bus.committed_rob_entries[i] <= '0;
      end

      // Keep popping entries starting from head until we get to a not busy entry
      for (int i = 0; i < COMMIT_WIDTH; i++) begin
        idx = head + i;

        commit_bus.committed_rob_entries[i] <= '0;

        if (!entries[idx].valid || entries[idx].busy || entries[idx].exception) begin
          break;
        end

        if (entries[idx].is_branch && !entries[idx].branch_info.resolved) begin
          break;
        end

        commit_bus.committed_rob_entries[i] <= entries[idx];

        entries[idx].valid <= 1'b0;

        $display("Committing ROB entry %d, PC=%0d", idx, entries[idx].PC);

        commit_count++;

      end

      head <= head + commit_count;

      // ------------------------------------------------------------
      // Dispatch (push to tail)
      // ------------------------------------------------------------
      if (bus.push && !bus.full) begin
        entries[tail] <= bus.push_entry;
        entries[tail].valid <= 1'b1;
        entries[tail].busy <= 1'b1;

        tail <= next_tail;
      end

      /// DEBUGGING
      if (wb_bus.alu_writeback.valid) begin
        ROB_entry_t entry;
        entry = entries[wb_bus.alu_writeback.rob_idx];
        `RV_ASSERT(
            entry.uop.has_rd,
            ("ALU writeback to instruction with no destination. ROB idx: %0d, PC: %0d", wb_bus.alu_writeback.rob_idx, entry.PC))
        `RV_ASSERT(
            wb_bus.alu_writeback.pdst == entry.uop.pdst,
            ("Invalid destination expected p%0d, recieved p%0d", wb_bus.alu_writeback.pdst, entry.uop.pdst))
        entries[wb_bus.alu_writeback.rob_idx].uop.dest_value <= wb_bus.alu_writeback.data;
        entries[wb_bus.alu_writeback.rob_idx].issued <= 1'b1;
      end

      if (wb_bus.mem_writeback.valid) begin
        ROB_entry_t entry;
        entry = entries[wb_bus.mem_writeback.rob_idx];
        `RV_ASSERT(
            entry.uop.has_rd,
            ("Memory writeback to instruction with no destination. ROB idx: %0d, PC: %0d", wb_bus.mem_writeback.rob_idx, entry.PC))
        `RV_ASSERT(
            wb_bus.mem_writeback.pdst == entry.uop.pdst,
            ("Invalid destination expected p%0d, recieved p%0d", wb_bus.mem_writeback.pdst, entry.uop.pdst))
        entries[wb_bus.mem_writeback.rob_idx].uop.dest_value <= wb_bus.mem_writeback.data;
        entries[wb_bus.mem_writeback.rob_idx].issued <= 1'b1;
      end

    end
  end

  always_comb begin
    bus.alu_wb_check_ok = 1'b0;
    bus.mem_wb_check_ok = 1'b0;

    if (bus.alu_wb_check_valid) begin
      bus.alu_wb_check_ok =
        entries[bus.alu_wb_check_rob_idx].valid &&
        entries[bus.alu_wb_check_rob_idx].PC == bus.alu_wb_check_PC;
    end

    if (bus.mem_wb_check_valid) begin
      bus.mem_wb_check_ok =
        entries[bus.mem_wb_check_rob_idx].valid &&
        entries[bus.mem_wb_check_rob_idx].PC == bus.mem_wb_check_PC;
    end
  end

endmodule : ReorderBuffer
