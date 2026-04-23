import riscv_types_pkg::*;
import riscv_lsu_types_pkg::*;

module LSU (
    input logic clk,
    input logic reset,

    STQ_if.LSU_side stq_bus,
    LDQ_if.LSU_side ldq_bus,
    Memory_Bus_if.Master_side mem_bus,
    RF_Write_if.User_side rf_write_bus
);

  always_comb begin
    mem_bus.read_en = 1'b0;
    mem_bus.write_en = '0;
    stq_bus.pop = 1'b0;
    mem_bus.addr = 32'b0;
    mem_bus.wdata = 32'b0;
    if (stq_bus.mem_store_valid) begin
      mem_bus.write_en = 1'b1;
      mem_bus.addr = stq_bus.mem_store_addr;
      mem_bus.wdata = stq_bus.mem_store_data;
      stq_bus.pop = 1'b1;
    end else if (ldq_bus.mem_load_valid) begin
      mem_bus.read_en = 1'b1;
      mem_bus.addr = ldq_bus.mem_load_addr;
    end
  end

  always_ff @(posedge clk) begin
    if (ldq_bus.mem_load_valid) begin
      rf_write_bus.en   <= 1'b1;
      rf_write_bus.data <= mem_bus.rdata;
      rf_write_bus.addr <= ldq_bus.mem_load_pdst;
    end
  end
endmodule : LSU
