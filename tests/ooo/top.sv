import testbench_utils_pkg::*;
import riscv_types_pkg::*;
import riscv_constants_pkg::*;
import riscv_rob_types_pkg::*;
import riscv_regs_types_pkg::*;

`include "riscv/util.svh"

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

  string elf_file;

  int unsigned memory_base;
  int unsigned entry_point;
  int unsigned loaded_size;

  import "DPI-C" function void dpi_load_elf(
    input string path,
    input int unsigned memory_size
  );

  import "DPI-C" function int unsigned dpi_get_elf_memory_base();
  import "DPI-C" function int unsigned dpi_get_elf_entry_point();
  import "DPI-C" function int unsigned dpi_get_elf_loaded_size();
  import "DPI-C" function byte unsigned dpi_get_elf_byte(input int unsigned offset);

  initial begin
    if (!$value$plusargs("elf=%s", elf_file)) begin
      `RV_ASSERT(0, ("Missing +elf=<file>"))
    end

    dpi_load_elf(elf_file, MEM_BYTES);

    memory_base = dpi_get_elf_memory_base();
    entry_point = dpi_get_elf_entry_point();
    loaded_size = dpi_get_elf_loaded_size();

    if (loaded_size > MEM_BYTES) begin
      `RV_ASSERT(0, ("ELF image too large: loaded_size=%0d MEM_BYTES=%0d", loaded_size, MEM_BYTES))
    end

    for (int unsigned i = 0; i < MEM_BYTES; i++) begin
      mem[i] = dpi_get_elf_byte(i);
    end

    $display("Loaded ELF: %s", elf_file);
    $display("  memory_base = %08h", memory_base);
    $display("  entry_point = %08h", entry_point);
    $display("  loaded_size = %0d bytes", loaded_size);
  end

  always_comb begin
    int unsigned addr;

    if (instr_bus.addr >= memory_base) begin
      addr = instr_bus.addr - memory_base;
    end else begin
      addr = MEM_BYTES;
    end

    instr_valid = (addr <= MEM_BYTES - 4);

    if (instr_valid) begin
      instr_bus.rdata = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr+0]};
    end else begin
      instr_bus.rdata = 32'h00000013;  // NOP
    end
  end

  always_comb begin
    int unsigned addr;

    if (data_bus.addr >= memory_base) begin
      addr = data_bus.addr - memory_base;
    end else begin
      addr = MEM_BYTES;
    end

    if (addr <= MEM_BYTES - 4) begin
      data_bus.rdata = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr+0]};
    end else begin
      data_bus.rdata = 32'hx;
    end
  end

  always_ff @(posedge clk) begin
    if (!reset && data_bus.write_en) begin
      int unsigned addr;

      if (data_bus.addr >= memory_base) begin
        addr = data_bus.addr - memory_base;
      end else begin
        addr = MEM_BYTES;
      end

      $display("STORE addr=%08h offset=%08h wdata=%08h", data_bus.addr, addr, data_bus.wdata);

      if (addr <= MEM_BYTES - 4) begin
        mem[addr+0] <= data_bus.wdata[7:0];
        mem[addr+1] <= data_bus.wdata[15:8];
        mem[addr+2] <= data_bus.wdata[23:16];
        mem[addr+3] <= data_bus.wdata[31:24];
      end else begin
        $display("WARNING: store outside mock memory addr=%08h", data_bus.addr);
      end
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

    if (a0 == 1) begin
      return 1;  // pass
    end else if (a0 > 1) begin
      return -1;  // fail
    end else begin
      return 0;  // still running
    end
  endfunction

  always_ff @(posedge clk) begin
    if (reset) begin
      cycle <= 0;
    end else begin
      cycle <= cycle + 1;
    end
  end

  import "DPI-C" function int unsigned on_commit(
    input int unsigned PC,
    input int unsigned IR,
    input int unsigned rd,
    input int unsigned rd_data,
    input int unsigned ls_addr,
    input int unsigned st_data
  );

  always_ff @(posedge clk) begin
    if (reset) begin
      // Do nothing on reset.
    end else begin
      for (int i = 0; i < COMMIT_WIDTH; i++) begin
        ROB_entry_t  entry;

        int unsigned pc;
        int unsigned ir;

        int unsigned rd;
        int unsigned rd_data;

        int unsigned ls_addr;
        int unsigned st_data;

        entry = dut.commit_bus.committed_rob_entries[i];

        if (entry.valid) begin
          pc = entry.PC;
          ir = entry.uop.inst;

          rd = x0;
          rd_data = 0;

          ls_addr = 0;
          st_data = 0;

          // ----------------------------
          // Register destination
          // ----------------------------
          if (entry.uop.has_rd && entry.uop.rd != 0) begin
            rd = 32'(entry.uop.rd);

            // TODO: Check if the rd_data is actually on the writeback bus
            // rd_data = dut.rf.regs[dut.renamer.RAT[entry.uop.rd]];

            rd_data = entry.uop.dest_value;
          end

          if (entry.uop.is_load) begin
            $display("Load commit: PC=%0d ld_addr=%0h rd=x%0d rd_data=%0h", entry.PC,
                     entry.load_addr, entry.uop.rd, entry.uop.dest_value);
            ls_addr = entry.load_addr;
          end

          if (entry.uop.is_store) begin
            $display("Store commit: PC=%0d st_addr=%0h st_data=%0h", entry.PC, entry.store_addr,
                     entry.store_data);
            ls_addr = entry.store_addr;
            st_data = entry.store_data;
          end

          void'(on_commit(pc, ir, rd, rd_data, ls_addr, st_data));

          $display("COMMIT cycle=%0d slot=%0d pc=%08h ir=%08h rd=x%0d rd_data=%08h rob=%0d", cycle,
                   i, pc, ir, rd, rd_data, entry.rob_idx);
        end
      end
    end
  end

endmodule
