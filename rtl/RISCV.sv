import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_rob_types_pkg::*;
import riscv_constants_pkg::*;
import riscv_decoder_types_pkg::*;

`include "riscv/util.svh"

module RISCV (
    input logic clk,
    input logic reset,
    Memory_Bus_if.Master_side instruction_mem_bus,
    input logic instr_valid,
    Memory_Bus_if.Master_side data_mem_bus
);

  // Interfaces
  IssueQueue_if alu_iq_bus ();
  IssueQueue_if mem_iq_bus ();
  ReorderBuffer_if rob_bus ();
  Writeback_if wb_bus ();
  STQ_if stq_bus ();
  LDQ_if ldq_bus ();

  Commit_if commit_bus ();

  RF_Read_if execution_alu_read_A_bus ();
  RF_Read_if execution_alu_read_B_bus ();
  RF_Write_if execution_alu_write_bus ();

  RF_Read_if execution_mem_read_A_bus ();
  RF_Read_if execution_mem_read_B_bus ();

  RF_Write_if lsu_write_bus ();

  addr_t PC;

  rat_output_t rat_out;

  decoder_input_t decoder_in;
  decoder_output_t decoder_out;

  logic advance_pipeline;

  branch_info_t branch_info;

  branch_info_t oldest_branch_info;

  flush_t flush_info;

  logic rename_stall;
  logic structural_stall;

  assign structural_stall =
    decoder_out.valid &&
    (
        rob_bus.full ||
        alu_iq_bus.full ||
        mem_iq_bus.full ||
        stq_bus.full ||
        ldq_bus.full
    );

  assign instruction_mem_bus.addr = PC;
  assign instruction_mem_bus.read_en = advance_pipeline;

  assign decoder_in.IR = instruction_mem_bus.rdata;
  assign decoder_in.PC = PC;

  logic just_released_reset;

  always_ff @(posedge clk) begin
    if (reset) begin
      just_released_reset <= 1;
    end else begin
      just_released_reset <= 0;
    end
  end

  always_comb begin
    flush_info = '0;

    if (oldest_branch_info.valid && oldest_branch_info.mispredict) begin
      flush_info.valid   = 1'b1;
      flush_info.rob_idx = oldest_branch_info.rob_idx;
      $display(
          "Branch mispredict detected at PC=%0d! Oldest mispredicted branch in ROB is at index %d, target=%0d",
          PC, oldest_branch_info.rob_idx, oldest_branch_info.target);
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      PC <= '0;
    end else begin
      if (flush_info.valid) begin
        PC <= oldest_branch_info.target;  // redirect
        $display("Flushing pipeline due to branch mispredict! Redirecting to PC=%0d",
                 oldest_branch_info.target);
        $fflush();
      end

      if (advance_pipeline) begin
        PC <= PC + 4;
      end
    end
  end

  assign advance_pipeline =
    instr_valid &&
    !flush_info.valid &&
    !just_released_reset &&
    !rename_stall &&
    !structural_stall;

  Decoder decoder (
      .clk(clk),
      .reset(reset),
      .advance_pipeline(advance_pipeline),
      .flush(flush_info.valid),
      .decoder_in(decoder_in),
      .stq_bus(stq_bus),
      .ldq_bus(ldq_bus),
      .decoder_out(decoder_out)
  );

  RegisterRenamer renamer (
      .clk(clk),
      .reset(reset),
      .commit_bus(commit_bus),
      .decoder_out(decoder_out),
      .flush_info(flush_info),
      .rename_stall(rename_stall),
      .rob_bus(rob_bus),
      .rat_out(rat_out),
      .wb_bus(wb_bus)
  );

  Dispatcher dispatcher (
      .alu_iq_bus(alu_iq_bus),
      .mem_iq_bus(mem_iq_bus),
      .rob_bus(rob_bus),
      .rat_out(rat_out)
  );

  IssueQueue alu_iq (
      .clk(clk),
      .reset(reset),
      .bus(alu_iq_bus),
      .wb_bus(wb_bus),
      .flush_info(flush_info),
      .rob_bus(rob_bus)
  );

  IssueQueue mem_iq (
      .clk(clk),
      .reset(reset),
      .bus(mem_iq_bus),
      .wb_bus(wb_bus),
      .flush_info(flush_info),
      .rob_bus(rob_bus)
  );

  ReorderBuffer rob (
      .clk(clk),
      .reset(reset),
      .commit_bus(commit_bus),
      .bus(rob_bus),
      .flush_info(flush_info),
      .branch_info(branch_info),
      .oldest_branch_info(oldest_branch_info),
      .wb_bus(wb_bus)
  );

  ExecutionUnit eu (
      .clk(clk),
      .reset(reset),
      .rob_bus(rob_bus),
      .alu_iq_bus(alu_iq_bus),
      .alu_a_bus(execution_alu_read_A_bus),
      .alu_b_bus(execution_alu_read_B_bus),
      .alu_write_bus(execution_alu_write_bus),
      .mem_iq_bus(mem_iq_bus),
      .mem_a_bus(execution_mem_read_A_bus),
      .mem_b_bus(execution_mem_read_B_bus),
      .stq_bus(stq_bus),
      .ldq_bus(ldq_bus),
      .branch_info(branch_info),
      .flush_info(flush_info)
  );

  RegisterFile rf (
      .clk(clk),
      .reset(reset),
      .wb_bus(wb_bus),
      .alu_read_A_bus(execution_alu_read_A_bus),
      .alu_read_B_bus(execution_alu_read_B_bus),
      .alu_write_bus(execution_alu_write_bus),
      .mem_read_A_bus(execution_mem_read_A_bus),
      .mem_read_B_bus(execution_mem_read_B_bus),
      .mem_write_bus(lsu_write_bus)
  );

  STQ stq (
      .clk(clk),
      .reset(reset),
      .bus(stq_bus),
      .commit_bus(commit_bus)
  );

  LDQ ldq (
      .clk(clk),
      .reset(reset),
      .bus(ldq_bus),
      .stq_bus(stq_bus),
      .rat_out(rat_out)
  );

  LSU lsu (
      .clk(clk),
      .reset(reset),
      .stq_bus(stq_bus),
      .rf_write_bus(lsu_write_bus),
      .ldq_bus(ldq_bus),
      .mem_bus(data_mem_bus)
  );

  // Rename-stall should not last forever when ROB/IQ are empty
  always_ff @(posedge clk) begin
    logic [7:0] rename_stall_count;
    if (reset || flush_info.valid || !rename_stall) begin
      rename_stall_count <= '0;
    end else begin
      rename_stall_count <= rename_stall_count + 1'b1;
      `RV_ASSERT(rename_stall_count < 8'd20,
                 ("Rename stall stuck: PC=%0d dec_pc=%0d rd=x%0d has_rd=%0b next_free_valid=%0b rob_head=%0d rob_tail=%0d",
                  PC,
                  decoder_out.uop.pc,
                  decoder_out.uop.rd,
                  decoder_out.uop.has_rd,
                  renamer.next_free.valid,
                 rob_bus.head_ptr, rob_bus.tail_ptr))
    end
  end

  always_ff @(posedge clk) begin
    if (!reset && rename_stall) begin
      $display(
          "STALL pc=%0d dec_pc=%0d rd=x%0d next_free=%0b ROB head=%0d tail=%0d head_pc=%0d head_busy=%0b head_valid=%0b head_rd=x%0d old=P%0d new=P%0d",
          PC, decoder_out.uop.pc, decoder_out.uop.rd, renamer.next_free.valid, rob_bus.head_ptr,
          rob_bus.tail_ptr, rob_bus.head_entry.PC, rob_bus.head_entry.busy,
          rob_bus.head_entry.valid, rob_bus.head_entry.rd, rob_bus.head_entry.old_dest,
          rob_bus.head_entry.new_dest);
    end
  end

  always_ff @(posedge clk) begin
    if (!reset && rename_stall) begin
      $display(
          "STALL head_pc=%0d head_rd=x%0d old=P%0d new=P%0d head_busy=%0b busy_old=%0b busy_new=%0b",
          rob_bus.head_entry.PC, rob_bus.head_entry.rd, rob_bus.head_entry.old_dest,
          rob_bus.head_entry.new_dest, rob_bus.head_entry.busy,
          renamer.busy_list[rob_bus.head_entry.old_dest],
          renamer.busy_list[rob_bus.head_entry.new_dest]);
    end
  end

endmodule : RISCV
