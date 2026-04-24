import riscv_types_pkg::*;

module MockMemory (
    input logic clk,
    input logic reset,
    Memory_Bus_if.Slave_side bus
);
  word_t mem[256];

  always_ff @(posedge clk) begin
    if (reset) begin
      for (int i = 0; i < 256; i++) begin
        mem[i] <= '0;
      end
    end else begin
      bus.rdata <= mem[bus.addr[9:2]];
      if (bus.write_en) begin
        mem[bus.addr[9:2]] <= bus.wdata;
      end
    end
  end

endmodule : MockMemory
