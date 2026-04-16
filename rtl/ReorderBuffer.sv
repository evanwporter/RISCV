import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_rob_types_pkg::*;
import constants_pkg::*;

module ReorderBuffer #(
    parameter ROB_SIZE  = 32,
    parameter PTR_WIDTH = $clog2(ROB_SIZE)
) (
    input logic clk,
    input logic reset,

    Writeback_if.ROB_Side wb_bus,
    ReorderBuffer_if.ROB_Side bus
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

      // Writeback: mark done
      if (wb_bus.valid) begin
        rob_entries[wb_bus.rob_idx].busy <= 1'b0;
      end

      // Commit (pop from head)
      for (i = 0; i < COMMIT_WIDTH; i++) begin
        idx = head + i;

        if (rob_entries[idx].valid && (!rob_entries[idx].busy || (wb_bus.valid && wb_bus.rob_idx == idx)) && !rob_entries[idx].exception) begin

          rob_entries[idx].valid <= 1'b0;
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
