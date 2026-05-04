import riscv_rob_types_pkg::*;
import riscv_constants_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_util_pkg::*;

module ReorderBuffer (
    input logic clk,
    input logic reset,

    input flush_t flush_info,

    input  branch_info_t branch_info,
    output branch_info_t oldest_branch_info,

    ReorderBuffer_if.ROB_Side bus,
    Commit_if.ROB_Side commit_bus
);

  ROB_entry_t entries[ROB_WIDTH];

  logic [ROB_IDX_WIDTH-1:0] head, tail;

  assign bus.head_entry = entries[head];
  assign bus.head_ptr = head;
  assign bus.tail_ptr = tail;
  assign bus.next_tail_ptr = tail + 1;

  logic [ROB_IDX_WIDTH-1:0] next_tail;
  assign next_tail = tail + 1;

  assign bus.full  = (next_tail == head);

  // TODO: This logic doesn't account for circular wraparound
  always_comb begin
    oldest_branch_info = '0;

    // Find oldest branch
    for (int i = 0; i < ROB_WIDTH; i++) begin
      if (entries[i].valid && entries[i].is_branch && !entries[i].branch_info.flushed && !entries[i].branch_info.resolved) begin
        $display("Oldest branch in ROB is at index %d, target=%0d, mispredict=%b", i,
                 entries[i].branch_info.target, entries[i].branch_info.mispredict);
        oldest_branch_info = entries[i].branch_info;
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

    end else if (flush_info.valid) begin
      // Invalidate younger entries
      for (int i = 0; i < ROB_WIDTH; i++) begin
        if (entries[i].valid) begin
          if (is_younger(i[ROB_IDX_WIDTH-1:0], flush_info.rob_idx)) begin
            $display("Flushing ROB entry %d, PC=%0d", i, entries[i].PC);
            $fflush();
            entries[i].valid <= 1'b0;
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

      // Clear commit bus before we start filling it with committed entries
      for (int i = 0; i < COMMIT_WIDTH; i++) begin
        commit_bus.committed_rob_entries[i] <= '0;
      end

      // Commit (keep popping entries starting from head until we get to a not busy entry)
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

      // Dispatch (push to tail)
      if (bus.push && !bus.full) begin
        entries[tail] <= bus.push_entry;
        entries[tail].valid <= 1'b1;
        entries[tail].busy <= 1'b1;

        tail <= next_tail;
      end

    end
  end

endmodule : ReorderBuffer
