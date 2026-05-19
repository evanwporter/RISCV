import riscv_types_pkg::*;
import riscv_lsu_types_pkg::*;
import riscv_constants_pkg::*;
import riscv_util_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_decoder_types_pkg::*;

module STQ (
    input logic clk,
    input logic reset,

    STQ_if.STQ_side bus,
    Commit_if.STQ_Side commit_bus,
    ReorderBuffer_if.IQ_Side rob_bus,
    input rat_output_t rat_out,
    input flush_t flush_info
);

  stq_entry_t entries[STQ_WIDTH];

  /// Count of valid entries in the queue
  logic [STQ_IDX_WIDTH:0] count;

  assign bus.full  = (count == STQ_WIDTH);
  assign bus.empty = (count == 0);

  // Only the oldest store can fire
  // TODO: we should be able to pop the head and push a new store in the same cycle, 
  // but for now we require an extra cycle to pop before pushing
  wire head_can_fire =
      !bus.pop && 
      entries[bus.head_idx].valid &&
      entries[bus.head_idx].committed &&
      entries[bus.head_idx].addr_valid &&
      entries[bus.head_idx].data_valid;

  assign bus.mem_store_valid = head_can_fire;
  assign bus.mem_store_addr  = entries[bus.head_idx].addr;
  assign bus.mem_store_data  = entries[bus.head_idx].data;
  assign bus.mem_store_idx   = bus.head_idx;

  genvar i;
  generate
    for (i = 0; i < STQ_WIDTH; i++) begin : g_out
      assign bus.entries[i] = entries[i];
      assign bus.valid_mask[i] = entries[i].valid;
    end
  endgenerate

  function automatic logic [STQ_IDX_WIDTH-1:0] stq_idx_add(input logic [STQ_IDX_WIDTH-1:0] idx,
                                                           input logic [STQ_IDX_WIDTH:0] amount);
    logic [STQ_IDX_WIDTH:0] tmp;
    begin
      tmp = idx + amount;
      if (tmp >= STQ_WIDTH) stq_idx_add = tmp - STQ_WIDTH;
      else stq_idx_add = tmp[STQ_IDX_WIDTH-1:0];
    end
  endfunction

  integer k;
  always_ff @(posedge clk) begin
    if (reset) begin
      bus.head_idx <= '0;
      bus.tail_idx <= '0;
      count <= '0;
      for (k = 0; k < STQ_WIDTH; k++) begin
        entries[k] <= '0;
      end
    end else if (flush_info.valid) begin

      int survivor_count;
      survivor_count = '0;

      // TODO: flush_instruction on rat_out?

      // Invalidate younger entries
      for (int j = 0; j < STQ_WIDTH; j++) begin
        if (entries[j].valid) begin
          if (is_younger(entries[j].rob_idx, flush_info.rob_idx, rob_bus.head_ptr)) begin
            entries[j] <= '0;
          end else begin
            survivor_count = survivor_count + 1;
          end
        end
      end

      count <= survivor_count[STQ_IDX_WIDTH:0];
      bus.tail_idx <= bus.head_idx + survivor_count[STQ_IDX_WIDTH-1:0];

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
      for (int j = 0; j < COMMIT_WIDTH; j++) begin
        if (commit_bus.committed_rob_entries[j].valid && commit_bus.committed_rob_entries[j].stq_idx_valid) begin
          entries[commit_bus.committed_rob_entries[j].stq_idx].committed <= 1'b1;
        end
      end

      // Fire oldest ready/committed store in program order
      if (bus.pop) begin
        entries[bus.head_idx] <= '0;
        bus.head_idx <= bus.head_idx + 1'b1;
        count <= count - 1'b1;
      end

      // Update entry when its renamed
      if (rat_out.valid && rat_out.uop.is_store) begin
        entries[rat_out.stq_idx].rob_idx <= rat_out.rob_idx;
        entries[rat_out.stq_idx].PC <= rat_out.uop.pc;
      end
    end
  end

endmodule
