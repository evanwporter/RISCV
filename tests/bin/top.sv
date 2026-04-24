module bin_top_tb (
    input logic clk,
    input logic reset
);

  Memory_Bus_if instruction_bus ();
  Memory_Bus_if data_bus ();

  MockMemory mockMemory (
      .clk  (clk),
      .reset(reset),
      .bus  (instruction_bus)
  );

  RISCV dut (
      .clk(clk),
      .reset(reset),
      .instruction_mem_bus(instruction_bus),
      .data_mem_bus(data_bus)
  );

endmodule : bin_top_tb
