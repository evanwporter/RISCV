import riscv_types_pkg::*;
import riscv_lsu_types_pkg::*;

module STQ #(
    parameter  int DEPTH = 4,
    localparam int IDX_W = $clog2(DEPTH)
) (
    input logic clk,
    input logic reset,

    STQ_if.STQ_side bus
);

  stq_entry_t entries[DEPTH];

  /// Head represents the oldest store in the queue, and only it may fire (pop from queue and send to memory)
  logic [IDX_W-1:0] head_idx;

  /// Count of valid entries in the queue
  logic [IDX_W:0] count;

  assign bus.full  = (count == DEPTH);
  assign bus.empty = (count == '0);

  // Only the oldest store can fire
  wire head_can_fire =
      entries[head_idx].valid &&
      entries[head_idx].committed &&
      entries[head_idx].addr_valid &&
      entries[head_idx].data_valid;

  assign bus.mem_store_valid = head_can_fire;
  assign bus.mem_store_addr  = entries[head_idx].addr;
  assign bus.mem_store_data  = entries[head_idx].data;

  genvar i;
  generate
    for (i = 0; i < DEPTH; i++) begin : g_out
      assign bus.entries[i] = entries[i];
      assign bus.valid_mask[i] = entries[i].valid;
    end
  endgenerate

  integer k;
  always_ff @(posedge clk) begin
    if (reset) begin
      head_idx <= '0;
      bus.tail_idx <= '0;
      count <= '0;
      for (k = 0; k < DEPTH; k++) begin
        entries[k] <= '0;
      end
    end else begin
      // Allocate
      if (bus.push && !bus.full) begin
        entries[bus.tail_idx] <= '0;
        entries[bus.tail_idx].valid <= 1'b1;
        bus.tail_idx <= bus.tail_idx + 1'b1;
        count <= count + 1'b1;
      end

      // Fill address
      if (bus.write_addr) begin
        entries[bus.write_addr_idx].addr_valid <= 1'b1;
        entries[bus.write_addr_idx].addr <= bus.write_addr_value;
      end

      // Fill data
      if (bus.write_data) begin
        entries[bus.write_data_idx].data_valid <= 1'b1;
        entries[bus.write_data_idx].data <= bus.write_data_value;
      end

      // Commit from ROB
      if (bus.commit) begin
        entries[bus.commit_idx].committed <= 1'b1;
      end

      // Fire oldest ready/committed store in program order
      if (bus.pop) begin
        entries[head_idx] <= '0;
        head_idx <= head_idx + 1'b1;
        count <= count - 1'b1;
      end
    end
  end

endmodule
