import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;

`include "riscv/util.svh"

module RegisterFile (
    input logic clk,
    input logic reset,

    Writeback_if.RegisterFile_Side wb_bus,

    RF_Read_if.RF_side  alu_read_A_bus,
    RF_Read_if.RF_side  alu_read_B_bus,
    RF_Write_if.RF_side alu_write_bus,

    RF_Read_if.RF_side  mem_read_A_bus,
    RF_Read_if.RF_side  mem_read_B_bus,
    RF_Write_if.RF_side mem_write_bus
);
  logic [31:0] regs[64];

  // Asynchronous reads
  always_comb begin
    alu_read_A_bus.data = 32'd0;
    if (alu_read_A_bus.en) begin
      alu_read_A_bus.data = regs[alu_read_A_bus.addr];
    end

    alu_read_B_bus.data = 32'd0;
    if (alu_read_B_bus.en) begin
      alu_read_B_bus.data = regs[alu_read_B_bus.addr];
    end
  end

  always_comb begin
    mem_read_A_bus.data = 32'd0;
    if (mem_read_A_bus.en) begin
      mem_read_A_bus.data = regs[mem_read_A_bus.addr];
    end

    mem_read_B_bus.data = 32'd0;
    if (mem_read_B_bus.en) begin
      mem_read_B_bus.data = regs[mem_read_B_bus.addr];
    end
  end

  // Synchronous write + reset
  always_ff @(posedge clk) begin
    if (reset) begin
      for (int i = 0; i < 64; i++) begin
        regs[i] <= '0;
      end
    end else begin
      `RV_ASSERT(regs[0] == 0, ("Error: Register x0 should always be zero"));

      wb_bus.alu_writeback.valid <= 0;
      wb_bus.alu_writeback.pdst  <= P0;
      if (alu_write_bus.en) begin
        wb_bus.alu_writeback.valid <= 1;
        wb_bus.alu_writeback.pdst <= alu_write_bus.addr;
        wb_bus.alu_writeback.PC <= alu_write_bus.PC;
        wb_bus.alu_writeback.rob_idx <= alu_write_bus.rob_idx;
        wb_bus.alu_writeback.data <= alu_write_bus.data;

        if (alu_write_bus.addr != P0) begin
          regs[alu_write_bus.addr] <= alu_write_bus.data;
        end
      end

      wb_bus.mem_writeback.valid <= 0;
      wb_bus.mem_writeback.pdst  <= P0;
      if (mem_write_bus.en) begin
        wb_bus.mem_writeback.valid <= 1;
        wb_bus.mem_writeback.pdst <= mem_write_bus.addr;
        wb_bus.mem_writeback.PC <= mem_write_bus.PC;
        wb_bus.mem_writeback.rob_idx <= mem_write_bus.rob_idx;
        wb_bus.mem_writeback.data <= mem_write_bus.data;

        if (mem_write_bus.addr != P0) begin
          regs[mem_write_bus.addr] <= mem_write_bus.data;
        end
      end
    end
  end

endmodule : RegisterFile
