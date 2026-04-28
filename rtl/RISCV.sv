import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_rob_types_pkg::*;
import riscv_constants_pkg::*;
import riscv_decoder_types_pkg::*;

module RISCV (
    input logic clk,
    input logic reset,
    Memory_Bus_if.Master_side instruction_mem_bus,
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

  word_t PC;

  rat_output_t rat_out;

  decoder_input_t decoder_in;
  decoder_output_t decoder_out;

  logic advance_pipeline;

  branch_info_t branch_info;

  branch_info_t oldest_branch_info;

  flush_t flush_info;

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

  logic pipeline_stalled;

  always_ff @(posedge clk) begin
    if (reset) begin
      PC <= '0;
    end else begin
      pipeline_stalled <= 1'b0;
      if (flush_info.valid) begin
        PC <= oldest_branch_info.target;  // redirect
        $display("Flushing pipeline due to branch mispredict! Redirecting to PC=%0d",
                 oldest_branch_info.target);
        $fflush();
        pipeline_stalled <= 1'b1;
      end

      if (advance_pipeline) begin
        PC <= PC + 4;
      end
    end
  end

  wire branch_detected = decoder_out.valid && decoder_out.uop.is_branch;

  assign advance_pipeline = !(pipeline_stalled || flush_info.valid || just_released_reset);

  // always_ff @(posedge clk) begin
  //   if (reset) begin
  //     pipeline_stalled <= 1'b0;
  //   end else begin
  //     if (branch_detected) begin
  //       pipeline_stalled <= 1'b1;
  //     end else if (branch_info.valid) begin
  //       pipeline_stalled <= 1'b0;
  //     end
  //   end
  // end

  Decoder decoder (
      .clk(clk),
      .reset(reset),
      .advance_pipeline(advance_pipeline),
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
      .flush_info(flush_info)
  );

  IssueQueue mem_iq (
      .clk(clk),
      .reset(reset),
      .bus(mem_iq_bus),
      .wb_bus(wb_bus),
      .flush_info(flush_info)
  );

  ReorderBuffer rob (
      .clk(clk),
      .reset(reset),
      .commit_bus(commit_bus),
      .bus(rob_bus),
      .flush_info(flush_info),
      .branch_info(branch_info),
      .oldest_branch_info(oldest_branch_info)
  );

  ExecutionUnit eu (
      .clk(clk),
      .reset(reset),
      .commit_bus(commit_bus),
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


endmodule : RISCV
