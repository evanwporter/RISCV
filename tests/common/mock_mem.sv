import riscv_types_pkg::*;

module MockMemory (
    input logic clk,
    input logic reset,
    Memory_Bus_if.Slave_side bus
);

  byte_t mem[256];

  always_comb begin
    bus.rdata = {mem[bus.addr+3], mem[bus.addr+2], mem[bus.addr+1], mem[bus.addr+0]};
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      for (int i = 0; i < 256; i++) begin
        mem[i] <= '0;
      end
    end else begin
      if (bus.write_en) begin
        mem[bus.addr+0] <= bus.wdata[7:0];
        mem[bus.addr+1] <= bus.wdata[15:8];
        mem[bus.addr+2] <= bus.wdata[23:16];
        mem[bus.addr+3] <= bus.wdata[31:24];
      end
    end
  end

endmodule : MockMemory
