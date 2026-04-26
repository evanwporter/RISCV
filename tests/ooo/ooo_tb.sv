import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_constants_pkg::*;
import riscv_decoder_types_pkg::*;
import riscv_lsu_types_pkg::*;
import testbench_utils_pkg::*;

`define EXPECT_EQ(actual, expected) \
  if ((actual) !== (expected)) begin \
    $display("[FAIL] %s:%0d | %s != %s | actual=%0d expected=%0d", \
      `__FILE__, `__LINE__, `"actual`", `"expected`", actual, expected); \
  end else begin \
    $display("[PASS] %s == %s | value=%0d", `"actual`", `"expected`", actual); \
  end

module ooo_tb;

  //   initial begin
  //     $dumpfile({get_dirname(`__FILE__), "/ooo_tb.vcd"});
  //     $dumpvars(0, ooo_tb);
  //   end

  //   logic clk;
  //   logic reset;

  //   // DUT signals
  //   rat_output_t rat_out;

  //   decoder_input_t decoder_in;
  //   decoder_output_t decoder_out;

  //   logic advance_pipeline;

  //   // Interfaces
  //   IssueQueue_if alu_iq_bus ();
  //   IssueQueue_if mem_iq_bus ();
  //   ReorderBuffer_if rob_bus ();
  //   Writeback_if wb_bus ();
  //   STQ_if stq_bus ();
  //   LDQ_if ldq_bus ();

  //   Commit_if commit_bus ();

  //   RF_Read_if execution_alu_read_A_bus ();
  //   RF_Read_if execution_alu_read_B_bus ();
  //   RF_Write_if execution_alu_write_bus ();

  //   RF_Read_if execution_mem_read_A_bus ();
  //   RF_Read_if execution_mem_read_B_bus ();
  //   RF_Write_if execution_mem_write_B_bus ();

  //   RF_Write_if lsu_write_bus ();

  //   Decoder decoder (
  //       .clk(clk),
  //       .reset(reset),
  //       .advance_pipeline(advance_pipeline),
  //       .decoder_in(decoder_in),
  //       .stq_bus(stq_bus),
  //       .ldq_bus(ldq_bus),
  //       .decoder_out(decoder_out)
  //   );

  //   RegisterRenamer renamer (
  //       .clk(clk),
  //       .reset(reset),
  //       .commit_bus(commit_bus),
  //       .decoder_out(decoder_out),
  //       .rat_out(rat_out),
  //       .wb_bus(wb_bus)
  //   );

  //   Dispatcher dispatcher (
  //       .alu_iq_bus(alu_iq_bus),
  //       .mem_iq_bus(mem_iq_bus),
  //       .rob_bus(rob_bus),
  //       .rat_out(rat_out)
  //   );

  //   IssueQueue alu_iq (
  //       .clk(clk),
  //       .reset(reset),
  //       .bus(alu_iq_bus),
  //       .wb_bus(wb_bus)
  //   );

  //   IssueQueue mem_iq (
  //       .clk(clk),
  //       .reset(reset),
  //       .bus(mem_iq_bus),
  //       .wb_bus(wb_bus)
  //   );

  //   ReorderBuffer rob (
  //       .clk(clk),
  //       .reset(reset),
  //       .wb_bus(wb_bus),
  //       .commit_bus(commit_bus),
  //       .bus(rob_bus),
  //       .stq_bus(stq_bus)
  //   );

  //   ExecutionUnit eu (
  //       .clk(clk),
  //       .reset(reset),
  //       .commit_bus(commit_bus),
  //       .alu_iq_bus(alu_iq_bus),
  //       .alu_a_bus(execution_alu_read_A_bus),
  //       .alu_b_bus(execution_alu_read_B_bus),
  //       .alu_write_bus(execution_alu_write_bus),
  //       .mem_iq_bus(mem_iq_bus),
  //       .mem_a_bus(execution_mem_read_A_bus),
  //       .mem_b_bus(execution_mem_read_B_bus),
  //       .mem_write_bus(execution_mem_write_B_bus),
  //       .stq_bus(stq_bus)
  //   );

  //   RegisterFile rf (
  //       .clk(clk),
  //       .reset(reset),
  //       .wb_bus(wb_bus),
  //       .execution_read_A_bus(execution_alu_read_A_bus),
  //       .execution_read_B_bus(execution_alu_read_B_bus),
  //       .execution_write_bus(execution_alu_write_bus)
  //   );

  //   STQ stq (
  //       .clk  (clk),
  //       .reset(reset),
  //       .bus  (stq_bus)
  //   );

  //   LDQ ldq (
  //       .clk  (clk),
  //       .reset(reset),
  //       .bus  (ldq_bus)
  //   );

  //   Memory_Bus_if cpu_bus ();

  //   MockMemory mockMemory (
  //       .clk  (clk),
  //       .reset(reset),
  //       .bus  (cpu_bus)
  //   );

  //   LSU lsu (
  //       .clk(clk),
  //       .reset(reset),
  //       .stq_bus(stq_bus),
  //       .rf_write_bus(lsu_write_bus),
  //       .ldq_bus(ldq_bus),
  //       .mem_bus(cpu_bus)
  //   );

  //   always #5 clk = ~clk;

  //   function word_t encode_r_type(input logic [4:0] rd, input logic [4:0] rs1, input logic [4:0] rs2);
  //     word_t instr;

  //     instr[6:0]   = 7'b0110011;  // OP
  //     instr[11:7]  = rd;
  //     instr[14:12] = 3'b000;  // funct3 (ADD)
  //     instr[19:15] = rs1;
  //     instr[24:20] = rs2;
  //     instr[31:25] = 7'b0000000;  // funct7

  //     return instr;
  //   endfunction

  //   function word_t encode_s_type(input logical_reg_t rs1, logical_reg_t rs2, input logic [11:0] imm);
  //     word_t instr;

  //     instr[6:0]   = 7'b0100011;  // STORE opcode
  //     instr[11:7]  = imm[4:0];
  //     instr[14:12] = 3'b010;  // SW
  //     instr[19:15] = rs1;  // base
  //     instr[24:20] = rs2;  // store data
  //     instr[31:25] = imm[11:5];

  //     return instr;
  //   endfunction

  //   initial begin
  //     clk = 0;
  //     reset = 1;

  //     advance_pipeline = 0;

  //     repeat (2) @(posedge clk);
  //     reset = 0;

  //     // ============================
  //     // CYCLE 0: x1 = x2, x3
  //     // ============================
  //     @(posedge clk);
  //     $display("\n=== Cycle 0 ===");
  //     decoder_in.IR = encode_r_type(x1, x2, x3);
  //     advance_pipeline = 1;

  //     $display("\n=== Cycle 1 ===");
  //     @(posedge clk);
  //     // Instruction 1 Decode

  //     `EXPECT_EQ(decoder_out.uop.rd, x1)

  //     decoder_in.IR = encode_r_type(x4, x1, x5);
  //     advance_pipeline = 1;

  //     // ============================
  //     // CYCLE 2: x4 = x1, x5
  //     // ============================
  //     @(posedge clk);
  //     $display("\n=== Cycle 2 ===");

  //     decoder_in.IR = encode_s_type(x6, x4, 12'd0);
  //     advance_pipeline = 1;

  //     $display("\n=== Instruction 1 Rename ===");
  //     `EXPECT_EQ(rat_out.Pd_new, P32)
  //     `EXPECT_EQ(rat_out.Pd_old, P1)
  //     `EXPECT_EQ(rat_out.Ps1, P2)
  //     `EXPECT_EQ(rat_out.Ps2, P3)
  //     `EXPECT_EQ(rat_out.advance_pipeline, 1)

  //     `EXPECT_EQ(alu_iq_bus.push, 1)

  //     $display("\n=== Instruction 2 Decode ===");
  //     `EXPECT_EQ(decoder_out.uop.rd, x4)

  //     // ============================
  //     // CYCLE 3
  //     // ============================
  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 3 ===");
  //     $display("===============");

  //     advance_pipeline = 0;

  //     $display("\n=== Instruction 1 Dispatch ===");
  //     `EXPECT_EQ(alu_iq.entries[0].valid, 1)
  //     `EXPECT_EQ(alu_iq.entries[0].pdst, P32)
  //     `EXPECT_EQ(alu_iq.entries[0].prs1, P2)
  //     `EXPECT_EQ(alu_iq.entries[0].prs2, P3)
  //     `EXPECT_EQ(alu_iq.entries[0].prs1_ready, 1)
  //     `EXPECT_EQ(alu_iq.entries[0].prs2_ready, 1)
  //     `EXPECT_EQ(alu_iq.entries[0].rob_idx, 0)

  //     `EXPECT_EQ(rob.rob_entries[0].valid, 1)
  //     `EXPECT_EQ(rob.rob_entries[0].busy, 1)
  //     `EXPECT_EQ(rob.rob_entries[0].old_dest, P1)
  //     `EXPECT_EQ(rob.rob_entries[0].new_dest, P32)

  //     $display("\n=== Instruction 2 Rename ===");
  //     `EXPECT_EQ(rat_out.Pd_new, P33)
  //     `EXPECT_EQ(rat_out.Pd_old, P4)
  //     `EXPECT_EQ(rat_out.Ps1, P32)
  //     `EXPECT_EQ(rat_out.Ps2, P5)

  //     $display("\n=== Instruction 3 Decode ===");
  //     `EXPECT_EQ(decoder_out.uop.rs1, x6)

  //     // ============================
  //     // CYCLE 4
  //     // ============================
  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 4 ===");
  //     $display("===============");

  //     $display("\n=== Instruction 1 Issue ===");
  //     `EXPECT_EQ(alu_iq_bus.issue_valid, 1)
  //     `EXPECT_EQ(alu_iq_bus.issue_entry.pdst, P32)
  //     `EXPECT_EQ(alu_iq_bus.issue_entry.prs1, P2)
  //     `EXPECT_EQ(alu_iq_bus.issue_entry.prs2, P3)
  //     `EXPECT_EQ(alu_iq_bus.issue_entry.prs1_ready, 1)
  //     `EXPECT_EQ(alu_iq_bus.issue_entry.prs2_ready, 1)
  //     `EXPECT_EQ(alu_iq_bus.issue_entry.rob_idx, 0)
  //     `EXPECT_EQ(alu_iq.entries[0].valid, 0)

  //     $display("\n=== Instruction 2 Dispatch ===");
  //     `EXPECT_EQ(alu_iq.entries[1].valid, 1)
  //     `EXPECT_EQ(alu_iq.entries[1].pdst, P33)
  //     `EXPECT_EQ(alu_iq.entries[1].prs1, P32)
  //     `EXPECT_EQ(alu_iq.entries[1].prs2, P5)
  //     `EXPECT_EQ(alu_iq.entries[1].prs1_ready, 0)
  //     `EXPECT_EQ(alu_iq.entries[1].prs2_ready, 1)
  //     `EXPECT_EQ(alu_iq.entries[1].rob_idx, 1)

  //     `EXPECT_EQ(rob.rob_entries[1].valid, 1)
  //     `EXPECT_EQ(rob.rob_entries[1].busy, 1)
  //     `EXPECT_EQ(rob.rob_entries[1].old_dest, P4)
  //     `EXPECT_EQ(rob.rob_entries[1].new_dest, P33)

  //     $display("\n=== Instruction 3 Allocate Store Entry ===");
  //     `EXPECT_EQ(stq.entries[0].valid, 1)


  //     // ============================
  //     // CYCLE 5
  //     // ============================
  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 5 ===");
  //     $display("===============");

  //     $display("\n=== Instruction 1 Execution ===");
  //     `EXPECT_EQ(execution_alu_write_bus.en, 1)
  //     `EXPECT_EQ(execution_alu_write_bus.rob_idx, 0)
  //     `EXPECT_EQ(execution_alu_write_bus.addr, P32)
  //     `EXPECT_EQ(execution_alu_write_bus.data, 0)

  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 6 ===");
  //     $display("===============");

  //     $display("\n=== Instruction 1 Commit in Progress ===");
  //     `EXPECT_EQ(rob.rob_entries[0].busy, 0)

  //     $display("\n=== Instruction 1 Writeback ===");

  //     `EXPECT_EQ(wb_bus.valid, 1)
  //     `EXPECT_EQ(wb_bus.pdst, P32)
  //     `EXPECT_EQ(wb_bus.rob_idx, 0)

  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 7 ===");
  //     $display("===============");

  //     $display("\n=== Instruction 1 Commited ===");
  //     `EXPECT_EQ(rob.rob_entries[0].valid, 0)
  //     `EXPECT_EQ(rob.head, 1)

  //     // $display("\n=== Instruction 2 Execution ===");
  //     // `EXPECT_EQ(execution_alu_write_bus.en, 1)
  //     // `EXPECT_EQ(execution_alu_write_bus.rob_idx, 1)
  //     // `EXPECT_EQ(execution_alu_write_bus.addr, P33)
  //     // `EXPECT_EQ(execution_alu_write_bus.data, 0)

  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 8 ===");
  //     $display("===============");

  //     $display("\n=== Instruction 1 Commit ===");

  //     `EXPECT_EQ(rob.rob_entries[0].busy, 0)
  //     `EXPECT_EQ(rob.rob_entries[0].valid, 0)
  //     `EXPECT_EQ(rob.head, 1)

  //     `EXPECT_EQ(alu_iq.entries[1].valid, 0)

  //     $display("\n=== Instruction 2 Issue ===");
  //     `EXPECT_EQ(alu_iq_bus.issue_valid, 1)
  //     `EXPECT_EQ(alu_iq_bus.issue_entry.pdst, P33)
  //     `EXPECT_EQ(alu_iq_bus.issue_entry.prs1, P32)
  //     `EXPECT_EQ(alu_iq_bus.issue_entry.prs2, P5)
  //     `EXPECT_EQ(alu_iq_bus.issue_entry.prs1_ready, 1)
  //     `EXPECT_EQ(alu_iq_bus.issue_entry.prs2_ready, 1)
  //     `EXPECT_EQ(alu_iq_bus.issue_entry.rob_idx, 1)
  //     `EXPECT_EQ(alu_iq.entries[1].valid, 0)

  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 9 ===");
  //     $display("===============");

  //     $display("\n=== Instruction 1 Execution ===");
  //     `EXPECT_EQ(execution_alu_write_bus.en, 1)
  //     `EXPECT_EQ(execution_alu_write_bus.rob_idx, 1)
  //     `EXPECT_EQ(execution_alu_write_bus.addr, P33)
  //     `EXPECT_EQ(execution_alu_write_bus.data, 0)

  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 10 ===");
  //     $display("===============");

  //     $display("\n=== Instruction 2 Writeback ===");

  //     `EXPECT_EQ(wb_bus.valid, 1)
  //     `EXPECT_EQ(wb_bus.pdst, P33)
  //     `EXPECT_EQ(wb_bus.rob_idx, 1)

  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 11 ===");
  //     $display("===============");

  //     $display("\n=== Instruction 2 Commit ===");

  //     `EXPECT_EQ(rob.rob_entries[1].busy, 0)
  //     `EXPECT_EQ(rob.rob_entries[1].valid, 0)
  //     `EXPECT_EQ(rob.head, 2)

  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 12 ===");
  //     $display("===============");

  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 13 ===");
  //     $display("===============");

  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 14 ===");
  //     $display("===============");

  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 15 ===");
  //     $display("===============");

  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 16 ===");
  //     $display("===============");

  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 17 ===");
  //     $display("===============");

  //     @(posedge clk);
  //     $display("\n===============");
  //     $display("=== Cycle 18 ===");
  //     $display("===============");

  //     @(posedge clk);
  //     @(posedge clk);
  //     @(posedge clk);
  //     @(posedge clk);
  //     @(posedge clk);

  //     repeat (10) @(posedge clk);

  //     $finish;
  //   end

endmodule
