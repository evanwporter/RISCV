import riscv_types_pkg::*;
import riscv_lsu_types_pkg::*;
import riscv_regs_types_pkg::*;

// TODO: Better handshakes between memory and the LSU.
module LSU (
    input logic clk,
    input logic reset,

    STQ_if.LSU_side stq_bus,
    LDQ_if.LSU_side ldq_bus,
    Memory_Bus_if.Master_side mem_bus,
    RF_Write_if.User_side rf_write_bus
);

  logic pop_next;

  always_comb begin
    mem_bus.read_en = 1'b0;
    mem_bus.write_en = 1'b0;
    mem_bus.addr = 32'b0;
    mem_bus.wdata = 32'b0;

    pop_next = 1'b0;

    if (stq_bus.mem_store_valid) begin
      mem_bus.write_en = 1'b1;
      mem_bus.addr = stq_bus.mem_store_addr;
      mem_bus.wdata = stq_bus.mem_store_data;

      pop_next = 1'b1;
    end else if (ldq_bus.mem_load_valid) begin
      mem_bus.read_en = 1'b1;
      mem_bus.addr = ldq_bus.mem_load_addr;
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      stq_bus.pop <= 1'b0;
    end else begin
      stq_bus.pop <= pop_next;
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      rf_write_bus.en <= 1'b0;
      rf_write_bus.data <= '0;
      rf_write_bus.addr <= P0;
      rf_write_bus.rob_idx <= '0;
      rf_write_bus.PC <= '0;
      ldq_bus.wb_valid <= 1'b0;
    end else begin
      rf_write_bus.en <= 1'b0;
      rf_write_bus.data <= '0;
      rf_write_bus.addr <= P0;
      rf_write_bus.rob_idx <= '0;
      rf_write_bus.PC <= '0;
      ldq_bus.wb_valid <= 1'b0;
      if (ldq_bus.mem_load_valid) begin
        rf_write_bus.en <= 1'b1;
        rf_write_bus.data <= mem_bus.rdata;
        rf_write_bus.addr <= ldq_bus.mem_load_pdst;
        rf_write_bus.rob_idx <= ldq_bus.mem_load_rob_idx;
        rf_write_bus.PC <= ldq_bus.mem_load_PC;

        ldq_bus.wb_valid <= 1'b1;
        ldq_bus.wb_idx <= ldq_bus.mem_load_idx;
      end
    end
  end
endmodule : LSU
