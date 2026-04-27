import riscv_types_pkg::*;
import riscv_lsu_types_pkg::*;
import riscv_constants_pkg::*;
import riscv_decoder_types_pkg::*;

module LDQ (
    input logic clk,
    input logic reset,

    LDQ_if.LDQ_side bus,
    STQ_if.STQ_side stq_bus,
    input rat_output_t rat_out
);

  ldq_entry_t entries[LDQ_WIDTH];
  logic [LDQ_IDX_WIDTH:0] count;

  logic full, empty;

  assign full  = (count == LDQ_WIDTH);
  assign empty = (count == 0);

  logic [STQ_WIDTH-1:0] stq_dep_mask;

  always_comb begin
    for (int i = 0; i < STQ_WIDTH; i++) begin
      stq_dep_mask[i] = stq_bus.entries[i].valid;
    end
  end

  integer k;
  always_ff @(posedge clk) begin
    if (reset) begin
      bus.tail_idx <= '0;
      count <= '0;
      for (k = 0; k < LDQ_WIDTH; k++) begin
        entries[k] <= '0;
      end
    end else begin
      // Allocate
      if (bus.push && !full) begin
        entries[bus.tail_idx] <= '0;
        entries[bus.tail_idx].valid <= 1'b1;
        entries[bus.tail_idx].st_dep_mask <= stq_dep_mask;
        bus.tail_idx <= bus.tail_idx + 1'b1;
        count <= count + 1'b1;
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
        if (entries[i].valid && entries[i].st_dep_mask == '0 && entries[i].addr_valid) begin
          bus.mem_load_valid <= 1'b1;
          bus.mem_load_addr  <= entries[i].addr;
          bus.mem_load_pdst  <= entries[i].pdst;

          // TODO: maybe we want to keep this valid until its committed/load completes
          entries[i].valid   <= 1'b0;
          break;
        end
      end

      if (rat_out.uop.is_load) begin
        entries[rat_out.ldq_idx].pdst <= rat_out.Pd_new;
      end
    end
  end

endmodule : LDQ
