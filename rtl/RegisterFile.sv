import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;

module RegisterFile (
    input logic clk,
    input logic reset,

    Writeback_if.RegisterFile_Side wb_bus,

    RF_Read_if.RF_side  execution_read_A_bus,
    RF_Read_if.RF_side  execution_read_B_bus,
    RF_Write_if.RF_side execution_write_bus
);
  logic [31:0] regs[64];

  // Asynchronous reads
  always_comb begin
    execution_read_A_bus.data = 32'd0;
    if (execution_read_A_bus.en) begin
      execution_read_A_bus.data = regs[execution_read_A_bus.addr];
    end

    execution_read_B_bus.data = 32'd0;
    if (execution_read_B_bus.en) begin
      execution_read_B_bus.data = regs[execution_read_B_bus.addr];
    end
  end

  // Synchronous write + reset
  always_ff @(posedge clk) begin
    if (reset) begin
      for (int i = 0; i < 64; i++) begin
        regs[i] <= '0;
      end
    end else begin
      assert (regs[0] == 0)
      else $error("Error: Register x0 should always be zero");

      wb_bus.valid <= 0;
      wb_bus.pdst <= P0;
      wb_bus.rob_idx <= '0;
      if (execution_write_bus.en) begin
        wb_bus.valid <= 1;
        wb_bus.pdst <= execution_write_bus.addr;
        wb_bus.rob_idx <= execution_write_bus.rob_idx;
        wb_bus.PC <= execution_write_bus.PC;
        if (execution_write_bus.addr != P0) begin
          regs[execution_write_bus.addr] <= execution_write_bus.data;
        end
      end
    end
  end

endmodule : RegisterFile
