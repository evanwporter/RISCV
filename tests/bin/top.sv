import testbench_utils_pkg::*;

import riscv_types_pkg::*;

module MockInstructionMemory (
    Memory_Bus_if.Slave_side bus
);

  word_t mem[256];

  string hex_file;

  initial begin
    // Try to get from command line
    if (!$value$plusargs("hex=%s", hex_file)) begin
      hex_file = "ls.hex";
    end

    $display("Loading program: %s", hex_file);
    $readmemh(hex_file, mem);
  end

  always_comb begin
    bus.rdata = mem[bus.addr[9:2]];
  end

endmodule : MockInstructionMemory

module bin_top_tb;
  logic clk;
  logic reset;

  Memory_Bus_if instruction_bus ();
  Memory_Bus_if data_bus ();

  // Clock
  initial clk = 0;
  always #5 clk = ~clk;

  // DUT
  RISCV dut (
      .clk(clk),
      .reset(reset),
      .instruction_mem_bus(instruction_bus),
      .data_mem_bus(data_bus)
  );

  // Memory
  MockInstructionMemory instr_mem (.bus(instruction_bus));

  MockMemory data_mem (
      .clk  (clk),
      .reset(reset),
      .bus  (data_bus)
  );

  initial begin
    $dumpfile({get_dirname(`__FILE__), "/bin_top_tb.vcd"});
    $dumpvars(0, bin_top_tb);
  end

  initial begin
    reset = 1;
    repeat (2) @(posedge clk);
    reset = 0;
  end

  int cycle = 0;

  always @(posedge clk) begin
    if (!reset) begin
      cycle++;

      // x10 = a0 (your pass/fail register)
      if (dut.rf.regs[dut.renamer.RAT[10]] == -1) begin
        $display("PASS at cycle %0d", cycle);
        $finish;
      end

      if (dut.rf.regs[dut.renamer.RAT[10]] != 32'd0 && dut.rf.regs[dut.renamer.RAT[10]] != -1) begin
        $display("FAIL at cycle %0d, test = %0d", cycle, dut.rf.regs[dut.renamer.RAT[10]]);
        $finish;
      end

      if (cycle > 200) begin
        $display("TIMEOUT");
        $finish;
      end
    end
  end

endmodule
