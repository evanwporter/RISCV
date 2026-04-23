import riscv_types_pkg::*;
import riscv_lsu_types_pkg::*;
import riscv_constants_pkg::*;

module LDQ (
    input logic clk,
    input logic reset,

    LDQ_if.LDQ_side bus
);

  ldq_entry_t entries[LDQ_WIDTH];
  logic [LDQ_IDX_WIDTH:0] count;

  logic full, empty;

  assign full  = (count == LDQ_WIDTH);
  assign empty = (count == 0);

  logic [STQ_WIDTH-1:0] stq_dep_mask;

  always_comb begin
    for (int i = 0; i < STQ_WIDTH; i++) begin
      stq_dep_mask[i] = bus.stq_entries[i].valid;
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
      if (bus.store_cleared) begin
        for (k = 0; k < LDQ_WIDTH; k++) begin
          entries[k].st_dep_mask[bus.store_cleared_idx] <= 1'b0;
        end
      end

      // Fill address
      if (bus.write_addr) begin
        entries[bus.write_addr_idx].addr_valid <= 1'b1;
        entries[bus.write_addr_idx].addr <= bus.write_addr_value;
      end

      // Find entries ready to be loaded
      for (int i = 0; i < LDQ_WIDTH; i++) begin
        if (entries[i].st_dep_mask == '0 && entries[i].addr_valid) begin
          bus.mem_load_valid <= 1'b1;
          bus.mem_load_addr  <= entries[i].addr;
        end
      end
    end
  end

endmodule : LDQ
