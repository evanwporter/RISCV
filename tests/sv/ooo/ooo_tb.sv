import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import constants_pkg::*;
import riscv_decoder_types_pkg::*;

`define EXPECT_EQ(actual, expected) \
  if ((actual) !== (expected)) begin \
    $display("[FAIL] %s:%0d | %s != %s | actual=%0d expected=%0d", \
      `__FILE__, `__LINE__, `"actual`", `"expected`", actual, expected); \
  end else begin \
    $display("[PASS] %s == %s | value=%0d", `"actual`", `"expected`", actual); \
  end

module ooo_tb;

  initial begin
    $dumpfile("ooo_tb.vcd");
    $dumpvars(0, ooo_tb);
  end

  logic clk;
  logic reset;

  // DUT signals
  word_t fetched_IR;
  uop_t uop;
  rat_output_t rat_out;

  logic [NUM_PHYSICAL_REGS-1:0] freed_list;

  logic advance_pipeline;

  // Dispatcher -> IQ/ROB
  logic decoder_valid;

  // Interfaces
  IssueQueue_if iq_if ();
  ReorderBuffer_if rob_if ();
  Writeback_if wb_bus ();

  Decoder decoder (
      .clk(clk),
      .reset(reset),
      .advance_pipeline(advance_pipeline),
      .fetched_IR(fetched_IR),
      .uop(uop),
      .valid(decoder_valid)
  );

  // DUTs
  RegisterRenamer renamer (
      .clk(clk),
      .reset(reset),
      .uop(uop),
      .freed_list(freed_list),
      .rat_out(rat_out),
      .advance_pipeline(decoder_valid),
      .wb_bus(wb_bus)
  );

  Dispatcher dispatcher (
      .iq_bus (iq_if),
      .rob_bus(rob_if),
      .rat_out(rat_out)
  );

  IssueQueue iq (
      .clk(clk),
      .reset(reset),
      .bus(iq_if),
      .wb_bus(wb_bus)
  );

  ReorderBuffer rob (
      .clk(clk),
      .reset(reset),
      .wb_bus(wb_bus),
      .bus(rob_if)
  );

  RF_Read_if execution_read_A_bus ();
  RF_Read_if execution_read_B_bus ();
  RF_Write_if execution_write_bus ();

  ExecutionUnit eu (
      .clk(clk),
      .reset(reset),
      .iq_bus(iq_if),
      .a_bus(execution_read_A_bus),
      .b_bus(execution_read_B_bus),
      .write_bus(execution_write_bus)
  );

  RegisterFile rf (
      .clk(clk),
      .reset(reset),
      .wb_bus(wb_bus),
      .execution_read_A_bus(execution_read_A_bus),
      .execution_read_B_bus(execution_read_B_bus),
      .execution_write_bus(execution_write_bus)
  );

  always #5 clk = ~clk;

  function word_t encode_r_type(input logic [4:0] rd, input logic [4:0] rs1, input logic [4:0] rs2);
    word_t instr;

    instr[6:0]   = 7'b0110011;  // OP
    instr[11:7]  = rd;
    instr[14:12] = 3'b000;  // funct3 (ADD)
    instr[19:15] = rs1;
    instr[24:20] = rs2;
    instr[31:25] = 7'b0000000;  // funct7

    return instr;
  endfunction

  initial begin
    clk = 0;
    reset = 1;

    freed_list = '0;
    advance_pipeline = 0;

    repeat (2) @(posedge clk);
    reset = 0;

    // ============================
    // CYCLE 0: x1 = x2, x3
    // ============================
    @(posedge clk);
    $display("\n=== Cycle 0 ===");
    fetched_IR = encode_r_type(x1, x2, x3);
    advance_pipeline = 1;

    $display("\n=== Cycle 1 ===");
    @(posedge clk);
    // Instruction 1 Decode

    `EXPECT_EQ(uop.rd, x1)

    fetched_IR = encode_r_type(x4, x1, x5);
    advance_pipeline = 1;

    // ============================
    // CYCLE 2: x4 = x1, x5
    // ============================
    @(posedge clk);
    $display("\n=== Cycle 2 ===");

    advance_pipeline = 0;

    $display("\n=== Instruction 1 Rename ===");
    `EXPECT_EQ(rat_out.Pd_new, P32)
    `EXPECT_EQ(rat_out.Pd_old, P1)
    `EXPECT_EQ(rat_out.Ps1, P2)
    `EXPECT_EQ(rat_out.Ps2, P3)
    `EXPECT_EQ(rat_out.advance_pipeline, 1)

    `EXPECT_EQ(iq_if.push, 1)

    $display("\n=== Instruction 2 Decode ===");
    `EXPECT_EQ(uop.rd, x4)

    // ============================
    // CYCLE 3
    // ============================
    @(posedge clk);
    $display("\n===============");
    $display("=== Cycle 3 ===");
    $display("===============");

    $display("\n=== Instruction 1 Dispatch ===");
    `EXPECT_EQ(iq.entries[0].valid, 1)
    `EXPECT_EQ(iq.entries[0].pdst, P32)
    `EXPECT_EQ(iq.entries[0].prs1, P2)
    `EXPECT_EQ(iq.entries[0].prs2, P3)
    `EXPECT_EQ(iq.entries[0].prs1_ready, 1)
    `EXPECT_EQ(iq.entries[0].prs2_ready, 1)
    `EXPECT_EQ(iq.entries[0].rob_idx, 0)

    `EXPECT_EQ(rob.rob_entries[0].valid, 1)
    `EXPECT_EQ(rob.rob_entries[0].busy, 1)
    `EXPECT_EQ(rob.rob_entries[0].old_dest, P1)
    `EXPECT_EQ(rob.rob_entries[0].new_dest, P32)

    $display("\n=== Instruction 2 Rename ===");
    `EXPECT_EQ(rat_out.Pd_new, P33)
    `EXPECT_EQ(rat_out.Pd_old, P4)
    `EXPECT_EQ(rat_out.Ps1, P32)
    `EXPECT_EQ(rat_out.Ps2, P5)

    // ============================
    // CYCLE 4
    // ============================
    @(posedge clk);
    $display("\n===============");
    $display("=== Cycle 4 ===");
    $display("===============");

    $display("\n=== Instruction 1 Issue ===");
    `EXPECT_EQ(iq_if.issue_valid, 1)
    `EXPECT_EQ(iq_if.issue_entry.pdst, P32)
    `EXPECT_EQ(iq_if.issue_entry.prs1, P2)
    `EXPECT_EQ(iq_if.issue_entry.prs2, P3)
    `EXPECT_EQ(iq_if.issue_entry.prs1_ready, 1)
    `EXPECT_EQ(iq_if.issue_entry.prs2_ready, 1)
    `EXPECT_EQ(iq_if.issue_entry.rob_idx, 0)
    `EXPECT_EQ(iq.entries[0].valid, 0)

    $display("\n=== Instruction 2 Dispatch ===");
    `EXPECT_EQ(iq.entries[1].valid, 1)
    `EXPECT_EQ(iq.entries[1].pdst, P33)
    `EXPECT_EQ(iq.entries[1].prs1, P32)
    `EXPECT_EQ(iq.entries[1].prs2, P5)
    `EXPECT_EQ(iq.entries[1].prs1_ready, 0)
    `EXPECT_EQ(iq.entries[1].prs2_ready, 1)
    `EXPECT_EQ(iq.entries[1].rob_idx, 1)

    `EXPECT_EQ(rob.rob_entries[1].valid, 1)
    `EXPECT_EQ(rob.rob_entries[1].busy, 1)
    `EXPECT_EQ(rob.rob_entries[1].old_dest, P4)
    `EXPECT_EQ(rob.rob_entries[1].new_dest, P33)

    // ============================
    // CYCLE 5
    // ============================
    @(posedge clk);
    $display("\n===============");
    $display("=== Cycle 5 ===");
    $display("===============");

    $display("\n=== Instruction 1 Execution ===");
    `EXPECT_EQ(execution_write_bus.en, 1)
    `EXPECT_EQ(execution_write_bus.rob_idx, 0)
    `EXPECT_EQ(execution_write_bus.addr, P32)
    `EXPECT_EQ(execution_write_bus.data, 0)

    @(posedge clk);
    $display("\n===============");
    $display("=== Cycle 6 ===");
    $display("===============");

    `EXPECT_EQ(wb_bus.valid, 1)
    `EXPECT_EQ(wb_bus.pdst, P32)
    `EXPECT_EQ(wb_bus.rob_idx, 0)

    @(posedge clk);
    $display("\n===============");
    $display("=== Cycle 7 ===");
    $display("===============");

    $display("\n=== Instruction 1 Commit ===");

    `EXPECT_EQ(rob.rob_entries[0].busy, 0)
    `EXPECT_EQ(rob.rob_entries[0].valid, 0)
    `EXPECT_EQ(rob.head, 1)

    `EXPECT_EQ(iq.entries[1].valid, 1)
    `EXPECT_EQ(iq.entries[1].pdst, P33)
    `EXPECT_EQ(iq.entries[1].prs1, P32)
    `EXPECT_EQ(iq.entries[1].prs2, P5)
    `EXPECT_EQ(iq.entries[1].prs1_ready, 1)
    `EXPECT_EQ(iq.entries[1].prs2_ready, 1)
    `EXPECT_EQ(iq.entries[1].rob_idx, 1)

    // $display("\n=== Instruction 2 Execution ===");
    // `EXPECT_EQ(execution_write_bus.en, 1)
    // `EXPECT_EQ(execution_write_bus.rob_idx, 1)
    // `EXPECT_EQ(execution_write_bus.addr, P33)
    // `EXPECT_EQ(execution_write_bus.data, 0)

    @(posedge clk);
    $display("\n===============");
    $display("=== Cycle 8 ===");
    $display("===============");

    $display("\n=== Instruction 2 Issue ===");
    `EXPECT_EQ(iq_if.issue_valid, 1)
    `EXPECT_EQ(iq_if.issue_entry.pdst, P33)
    `EXPECT_EQ(iq_if.issue_entry.prs1, P32)
    `EXPECT_EQ(iq_if.issue_entry.prs2, P5)
    `EXPECT_EQ(iq_if.issue_entry.prs1_ready, 1)
    `EXPECT_EQ(iq_if.issue_entry.prs2_ready, 1)
    `EXPECT_EQ(iq_if.issue_entry.rob_idx, 1)
    `EXPECT_EQ(iq.entries[1].valid, 0)

    @(posedge clk);
    $display("\n===============");
    $display("=== Cycle 9 ===");
    $display("===============");

    $display("\n=== Instruction 1 Execution ===");
    `EXPECT_EQ(execution_write_bus.en, 1)
    `EXPECT_EQ(execution_write_bus.rob_idx, 1)
    `EXPECT_EQ(execution_write_bus.addr, P33)
    `EXPECT_EQ(execution_write_bus.data, 0)

    @(posedge clk);
    $display("\n===============");
    $display("=== Cycle 10 ===");
    $display("===============");

    $display("\n=== Instruction 2 Writeback ===");

    `EXPECT_EQ(wb_bus.valid, 1)
    `EXPECT_EQ(wb_bus.pdst, P33)
    `EXPECT_EQ(wb_bus.rob_idx, 1)

    @(posedge clk);
    $display("\n===============");
    $display("=== Cycle 11 ===");
    $display("===============");

    $display("\n=== Instruction 2 Commit ===");

    `EXPECT_EQ(rob.rob_entries[1].busy, 0)
    `EXPECT_EQ(rob.rob_entries[1].valid, 0)
    `EXPECT_EQ(rob.head, 2)

    $finish;
  end

endmodule
