import riscv_rob_types_pkg::*;
import riscv_constants_pkg::*;

module ReorderBuffer #(
    parameter ROB_SIZE  = 32,
    parameter PTR_WIDTH = $clog2(ROB_SIZE)
) (
    input logic clk,
    input logic reset,

    Writeback_if.ROB_Side wb_bus,
    ReorderBuffer_if.ROB_Side bus,
    STQ_if.ROB_side stq_bus
);

  ROB_entry_t rob_entries[ROB_SIZE];

  logic [PTR_WIDTH-1:0] head, tail;

  assign bus.head_entry = rob_entries[head];
  assign bus.head_ptr = head;
  assign bus.tail_ptr = tail;
  assign bus.next_tail_ptr = tail + 1;

  logic [PTR_WIDTH-1:0] next_tail;
  assign next_tail = tail + 1;

  assign bus.full  = (next_tail == head);

  always_ff @(posedge clk) begin
    logic [PTR_WIDTH-1:0] idx;
    /// TODO replace i w/ commit_count
    int i;
    logic [4:0] commit_count;
    commit_count = 0;

    if (reset) begin
      head <= '0;
      tail <= '0;

      for (int j = 0; j < ROB_SIZE; j++) begin
        rob_entries[j] <= '0;
      end

    end else begin

      if (bus.executed_op_valid) begin
        rob_entries[bus.executed_op_rob_idx] <= 1'b0;
      end

      stq_bus.commit <= 1'b0;

      // Commit (pop from head)
      for (i = 0; i < COMMIT_WIDTH; i++) begin
        idx = head + i;

        if (rob_entries[idx].valid && (!rob_entries[idx].busy || 
            (bus.executed_op_valid && bus.executed_op_rob_idx == idx)) && 
            !rob_entries[idx].exception) begin

          rob_entries[idx].valid <= 1'b0;

          // TODO: Handle multiple commits per cycle
          if (rob_entries[idx].stq_idx_valid) begin
            stq_bus.commit <= 1'b1;
            stq_bus.commit_idx <= rob_entries[idx].stq_idx;
          end

          commit_count++;

        end else begin
          break;
        end
      end

      head <= head + commit_count;

      // Dispatch (push to tail)
      if (bus.push && !bus.full) begin
        rob_entries[tail] <= bus.push_entry;
        rob_entries[tail].valid <= 1'b1;
        rob_entries[tail].busy <= 1'b1;

        tail <= next_tail;
      end

    end
  end

endmodule : ReorderBuffer
