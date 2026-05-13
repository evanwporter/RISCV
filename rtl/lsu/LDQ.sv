import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_lsu_types_pkg::*;
import riscv_constants_pkg::*;
import riscv_decoder_types_pkg::*;
import riscv_util_pkg::*;

// TODO: `LDQ` must behave less like a FIFO, and more like a IQ.
// We use find first free index. Since entries in the load queue, 
// can pop out of order (when their load completes).
module LDQ (
    input logic clk,
    input logic reset,

    LDQ_if.LDQ_side bus,
    STQ_if.STQ_side stq_bus,
    ReorderBuffer_if.IQ_Side rob_bus,
    input rat_output_t rat_out,
    input flush_t flush_info
);

  ldq_entry_t entries[LDQ_WIDTH];

  logic [STQ_WIDTH-1:0] stq_dep_mask;

  always_comb begin
    for (int i = 0; i < STQ_WIDTH; i++) begin
      stq_dep_mask[i] = stq_bus.entries[i].valid;
    end
  end

  // Find first free slot (for push)
  logic found_free;

  // If we found a free slot, then the queue is not full
  assign bus.full = !found_free;

  always_comb begin
    found_free   = 1'b0;
    bus.free_idx = '0;

    for (int unsigned i = 0; i < LDQ_WIDTH; i++) begin
      if (!entries[i].valid && !found_free) begin
        bus.free_idx = LDQ_IDX_WIDTH'(i);
        found_free   = 1'b1;
      end
    end
  end

  integer k;
  always_ff @(posedge clk) begin
    if (reset) begin
      for (k = 0; k < LDQ_WIDTH; k++) begin
        entries[k].valid <= 0;
      end

      bus.mem_load_valid <= 1'b0;
      bus.mem_load_addr  <= '0;

    end else if (flush_info.valid) begin

      bus.mem_load_valid <= 1'b0;
      bus.mem_load_addr  <= '0;

      // Invalidate younger entries
      for (int j = 0; j < LDQ_WIDTH; j++) begin
        if (entries[j].valid) begin
          if (is_younger(entries[j].rob_idx, flush_info.rob_idx, rob_bus.head_ptr)) begin
            entries[j].valid <= 1'b0;
            entries[j] <= '0;
          end
        end
      end

    end else begin
      // Allocate
      if (bus.push && !bus.full) begin
        entries[bus.free_idx] <= '0;
        entries[bus.free_idx].valid <= 1'b1;
        entries[bus.free_idx].issued <= 1'b0;
        entries[bus.free_idx].st_dep_mask <= stq_dep_mask;
      end

      // Clear dep bit when a store leaves STQ
      if (stq_bus.pop) begin
        for (k = 0; k < LDQ_WIDTH; k++) begin
          entries[k].st_dep_mask[stq_bus.head_idx] <= 1'b0;
        end
      end

      // Fill address
      if (bus.write_addr) begin
        entries[bus.write_addr_idx].addr_valid <= 1'b1;
        entries[bus.write_addr_idx].addr <= bus.write_addr_value;
      end

      // Find entries ready to be loaded
      bus.mem_load_valid <= 1'b0;
      bus.mem_load_addr  <= '0;
      for (int i = 0; i < LDQ_WIDTH; i++) begin
        if (entries[i].valid && entries[i].st_dep_mask == '0 && entries[i].addr_valid && !entries[i].issued) begin
          bus.mem_load_valid <= 1'b1;
          bus.mem_load_addr <= entries[i].addr;
          bus.mem_load_pdst <= entries[i].pdst;
          bus.mem_load_rob_idx <= entries[i].rob_idx;
          bus.mem_load_PC <= entries[i].PC;
          bus.mem_load_idx <= i;
          entries[i].issued <= 1'b1;
          break;
        end
      end

      if (bus.wb_valid) begin
        entries[bus.wb_idx].valid  <= 1'b0;
        entries[bus.wb_idx].issued <= 1'b0;
      end

      if (rat_out.valid && rat_out.uop.is_load) begin
        entries[rat_out.ldq_idx].pdst <= rat_out.Pd_new;
        entries[rat_out.ldq_idx].rob_idx <= rat_out.rob_idx;
        entries[rat_out.ldq_idx].PC <= rat_out.uop.pc;
      end
    end
  end

endmodule : LDQ
