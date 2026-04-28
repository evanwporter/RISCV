import testbench_utils_pkg::*;
import riscv_types_pkg::*;
import riscv_constants_pkg::*;

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

module ooo_top_tb (
    input logic clk,
    input logic reset
);

  typedef struct {
    logic [31:0] Fetched_PC;
    logic [31:0] Decoded_PC;
    logic [31:0] Renamed_PC;
    logic [31:0] Dispatched_PC;
    logic [31:0] Issued_PC;
    logic [31:0] Executed_PC;
  } cycle_snapshot_t;

  (* maybe_unused *)
  function cycle_snapshot_t get_snapshot();  /*verilator public*/
    cycle_snapshot_t snapshot;
    snapshot.Fetched_PC = dut.PC;
    snapshot.Decoded_PC = dut.decoder_out.uop.pc;
    snapshot.Renamed_PC = dut.rat_out.uop.pc;
    snapshot.Dispatched_PC = dut.rob_bus.push_entry.PC;
    snapshot.Issued_PC = dut.alu_iq_bus.issue_entry.uop.pc;
    snapshot.Executed_PC = dut.execution_alu_write_bus.PC;
    return snapshot;
  endfunction

  (* maybe_unused *)
  function void get_rob_entries(output int pc[ROB_WIDTH], output int valid[ROB_WIDTH],
                                output int busy[ROB_WIDTH]);
    for (int i = 0; i < ROB_WIDTH; i++) begin
      pc[i] = dut.rob.entries[i].PC;
      valid[i] = dut.rob.entries[i].valid;
      busy[i] = dut.rob.entries[i].busy;
    end
  endfunction

  (* maybe_unused *)
  function void get_iq_entries(output int pc[IQ_WIDTH], output int valid[IQ_WIDTH],
                               output int prs1[IQ_WIDTH], output int prs2[IQ_WIDTH]);
    for (int i = 0; i < IQ_WIDTH; i++) begin
      pc[i] = dut.alu_iq.entries[i].uop.pc;
      valid[i] = dut.alu_iq.entries[i].valid;
      prs1[i] = dut.alu_iq.entries[i].prs1_ready;
      prs2[i] = dut.alu_iq.entries[i].prs2_ready;
    end
  endfunction

  export "DPI-C" function get_rob_entries;
  export "DPI-C" function get_iq_entries;

  Memory_Bus_if instruction_bus ();
  Memory_Bus_if data_bus ();

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

  int cycle = 0;

  always @(posedge clk) begin
    if (!reset) begin
      cycle++;

      // x10 = a0 (your pass/fail register)
      if (dut.rf.regs[dut.renamer.ARAT[10]] == -1) begin
        $display("PASS at cycle %0d", cycle);
        $finish;
      end

      if (dut.rf.regs[dut.renamer.ARAT[10]] != 32'd0 && dut.rf.regs[dut.renamer.ARAT[10]] != -1) begin
        $display("FAIL at cycle %0d, test = %0d", cycle, dut.rf.regs[dut.renamer.ARAT[10]]);
        $finish;
      end

      if (cycle > 50) begin
        $display("TIMEOUT");
        $finish;
      end
    end
  end

endmodule
