import testbench_utils_pkg::*;
import riscv_types_pkg::*;
import riscv_constants_pkg::*;

module MockInstructionMemory (
    Memory_Bus_if.Slave_side bus,
    output logic instr_valid
);

  word_t mem[4096];

  string hex_file;
  int unsigned program_words;

  initial begin
    // Try to get from command line
    if (!$value$plusargs("hex=%s", hex_file)) begin
      hex_file = "ls.hex";
    end

    $display("Loading program: %s", hex_file);
    $readmemh(hex_file, mem);
  end

  initial begin
    string line;
    int fd;
    int code;
    word_t dummy;

    program_words = 0;

    // Re-open file only to count instruction words.
    fd = $fopen(hex_file, "r");
    if (fd == 0) begin
      $fatal(1, "Could not open hex file: %s", hex_file);
    end

    while (!$feof(
        fd
    )) begin
      line = "";
      code = $fgets(line, fd);

      if (code != 0) begin
        // Try to parse a hex word from the line.
        // Lines that do not start with hex data are ignored.
        if ($sscanf(line, "%h", dummy) == 1) begin
          program_words++;
        end
      end
    end

    $fclose(fd);

    $display("Loaded %0d instruction words", program_words);
  end

  always_comb begin
    int unsigned idx;

    // instr_valid = 1'b1;
    // bus.rdata = mem[bus.addr[31:2]];

    idx = bus.addr[31:2];

    instr_valid = idx < program_words;

    if (idx < program_words) begin
      bus.rdata = mem[idx];
      $display("Instruction Memory read: addr=%0h, data=%0h", bus.addr, bus.rdata);
    end else begin
      bus.rdata = 32'h00000013;
    end
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
  function void get_alu_iq_entries(output int pc[IQ_WIDTH], output int valid[IQ_WIDTH],
                                   output int prs1[IQ_WIDTH], output int prs2[IQ_WIDTH]);
    for (int i = 0; i < IQ_WIDTH; i++) begin
      pc[i] = dut.alu_iq.entries[i].uop.pc;
      valid[i] = dut.alu_iq.entries[i].valid;
      prs1[i] = dut.alu_iq.entries[i].prs1_ready;
      prs2[i] = dut.alu_iq.entries[i].prs2_ready;
    end
  endfunction

  (* maybe_unused *)
  function void get_mem_iq_entries(output int pc[IQ_WIDTH], output int valid[IQ_WIDTH],
                                   output int prs1[IQ_WIDTH], output int prs2[IQ_WIDTH]);
    for (int i = 0; i < IQ_WIDTH; i++) begin
      pc[i] = dut.mem_iq.entries[i].uop.pc;
      valid[i] = dut.mem_iq.entries[i].valid;
      prs1[i] = dut.mem_iq.entries[i].prs1_ready;
      prs2[i] = dut.mem_iq.entries[i].prs2_ready;
    end
  endfunction

  (* maybe_unused *)
  function void get_rename_debug(
      output int valid, output int pc, output int rs1_arch, output int rs2_arch, output int rd_arch,

      output int ps1, output int ps2, output int pd_old, output int pd_new, output int ps1_ready,
      output int ps2_ready, output int is_load, output int is_store, output int is_branch,

      output int rob_idx, output int stq_idx, output int ldq_idx, output int watch_arch[6],
      output int watch_phys[6], output int watch_ready[6], output int watch_busy[6]);
    valid = dut.rat_out.advance_pipeline;
    pc = dut.rat_out.uop.pc;

    rs1_arch = dut.rat_out.uop.rs1;
    rs2_arch = dut.rat_out.uop.rs2;
    rd_arch = dut.rat_out.uop.rd;

    ps1 = dut.rat_out.Ps1;
    ps2 = dut.rat_out.Ps2;
    pd_old = dut.rat_out.Pd_old;
    pd_new = dut.rat_out.Pd_new;

    ps1_ready = dut.rat_out.Ps1_ready;
    ps2_ready = dut.rat_out.Ps2_ready;

    is_load = dut.rat_out.uop.is_load;
    is_store = dut.rat_out.uop.is_store;
    is_branch = dut.rat_out.uop.is_branch;

    rob_idx = dut.rob_bus.tail_ptr;
    stq_idx = dut.rat_out.stq_idx;
    ldq_idx = dut.rat_out.ldq_idx;

    watch_arch[0] = 1;
    watch_arch[1] = 2;
    watch_arch[2] = 3;
    watch_arch[3] = 4;
    watch_arch[4] = 10;
    watch_arch[5] = 31;

    for (int i = 0; i < 6; i++) begin
      watch_phys[i]  = dut.renamer.RAT[watch_arch[i]];
      watch_busy[i]  = dut.renamer.busy_list[dut.renamer.RAT[watch_arch[i]]];
      watch_ready[i] = ~dut.renamer.busy_list[dut.renamer.RAT[watch_arch[i]]];
    end
  endfunction

  export "DPI-C" function get_rob_entries;
  export "DPI-C" function get_alu_iq_entries;
  export "DPI-C" function get_mem_iq_entries;
  export "DPI-C" function get_rename_debug;

  Memory_Bus_if instruction_bus ();
  Memory_Bus_if data_bus ();

  logic instr_valid;

  // DUT
  RISCV dut (
      .clk(clk),
      .reset(reset),
      .instruction_mem_bus(instruction_bus),
      .data_mem_bus(data_bus),
      .instr_valid(instr_valid)
  );

  // Memory
  MockInstructionMemory instr_mem (
      .bus(instruction_bus),
      .instr_valid(instr_valid)
  );

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

      if (cycle > 1000) begin
        $display("TIMEOUT");
        $finish;
      end
    end
  end

endmodule
