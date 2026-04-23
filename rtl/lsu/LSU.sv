import riscv_types_pkg::*;
import riscv_lsu_types_pkg::*;

module LSU (
    input logic clk,
    input logic reset,

    STQ_if.LSU_side stq_bus,
    Memory_Bus_if.Master_side mem_bus
);

  always_ff @(posedge clk) begin
    if (reset) begin
      mem_bus.read_en <= 1'b0;
      mem_bus.write_en <= '0;
      stq_bus.pop <= 1'b0;
    end else begin
      mem_bus.read_en <= 1'b0;
      mem_bus.write_en <= '0;
      stq_bus.pop <= 1'b0;
      if (stq_bus.mem_store_valid) begin
        mem_bus.write_en <= 1'b1;
        mem_bus.addr <= stq_bus.mem_store_addr;
        mem_bus.wdata <= stq_bus.mem_store_data;
        stq_bus.pop <= 1'b1;
      end
    end
  end
endmodule : LSU
