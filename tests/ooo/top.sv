import testbench_utils_pkg::*;
import riscv_types_pkg::*;
import riscv_constants_pkg::*;

module MockInstructionMemory (
    input logic clk,
    input logic reset,
    Memory_Bus_if.Slave_side instr_bus,
    Memory_Bus_if.Slave_side data_bus,
    output logic instr_valid
);

  localparam int MEM_DEPTH_WORDS = 4096;
  localparam int MEM_BYTES = MEM_DEPTH_WORDS * 4;

  logic [7:0] mem[0:MEM_BYTES-1];

  string hex_file;
  int unsigned program_words;

  initial begin
    string line;
    int fd;
    int code;
    word_t word;
    int unsigned addr;

    program_words = 0;

    // Re-open file only to count instruction words.
    if (!$value$plusargs("hex=%s", hex_file)) begin
      $fatal(1, "Missing +hex=<file>");
    end

    fd = $fopen(hex_file, "r");
    if (fd == 0) begin
      $error(1, "Could not open hex file: %s", hex_file);
    end

    addr = 0;

    while (!$feof(
        fd
    )) begin
      line = "";
      code = $fgets(line, fd);

      // Try to parse a hex word from the line.
      // Lines that do not start with hex data are ignored.
      if (code != 0 && $sscanf(line, "%h", word) == 1) begin
        if (addr + 3 >= MEM_BYTES) begin
          $fatal(1, "Hex file too large for mock memory: %s", hex_file);
        end

        // RISC-V little-endian word layout
        mem[addr+0] = word[7:0];
        mem[addr+1] = word[15:8];
        mem[addr+2] = word[23:16];
        mem[addr+3] = word[31:24];

        addr += 4;
        program_words++;
      end
    end

    $fclose(fd);

    $display("Loaded %0d words from %s", program_words, hex_file);
  end

  always_comb begin
    int unsigned addr;
    addr = instr_bus.addr;

    instr_valid = (addr <= MEM_BYTES - 4);

    if (instr_valid) begin
      instr_bus.rdata = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr+0]};
    end else begin
      instr_bus.rdata = 32'h00000013;  // NOP
    end
  end

  always_comb begin
    int unsigned addr;
    addr = data_bus.addr;

    if (addr <= MEM_BYTES - 4) begin
      data_bus.rdata = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr+0]};
    end else begin
      data_bus.rdata = 32'hx;
    end
  end

  always_ff @(posedge clk) begin
    if (!reset && data_bus.write_en) begin
      int unsigned addr;
      addr = data_bus.addr;

      $display("STORE addr=%h wdata=%h", data_bus.addr, data_bus.wdata);

      if (addr <= MEM_BYTES - 4) begin
        mem[addr+0] <= data_bus.wdata[7:0];
        mem[addr+1] <= data_bus.wdata[15:8];
        mem[addr+2] <= data_bus.wdata[23:16];
        mem[addr+3] <= data_bus.wdata[31:24];
      end
    end
  end

endmodule

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
    valid = dut.rat_out.valid;
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
      .clk(clk),
      .reset(reset),
      .instr_bus(instruction_bus),
      .data_bus(data_bus),
      .instr_valid(instr_valid)
  );

  int unsigned cycle = 0;

  (* maybe_unused *)
  function int unsigned get_cycle();  /*verilator public*/
    return cycle;
  endfunction

  (* maybe_unused *)
  function int get_a0();  /*verilator public*/
    return dut.rf.regs[dut.renamer.ARAT[10]];
  endfunction

  (* maybe_unused *)
  function int get_test_status();  /*verilator public*/
    int a0;
    a0 = dut.rf.regs[dut.renamer.ARAT[10]];

    if (a0 == -1) begin
      return 1;  // pass
    end else if (a0 != 0) begin
      return -1;  // fail
    end else begin
      return 0;  // still running
    end
  endfunction

  always @(posedge clk) begin
    if (reset) begin
      cycle <= 0;
    end else begin
      cycle <= cycle + 1;
    end
  end

endmodule
