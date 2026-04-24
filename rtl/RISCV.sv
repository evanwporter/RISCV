import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_rob_types_pkg::*;
import riscv_constants_pkg::*;
import riscv_decoder_types_pkg::*;

module RISCV (
    input logic clk,
    input logic reset
    // Memory_Bus_if.Master_side instruction_mem_bus,
    // Memory_Bus_if.Master_side data_mem_bus
);

  //   word_t PC;

  //   word_t fetched_IR;
  //   rat_output_t rat_out;

  //   decoder_output_t decoder_out;

  //   logic advance_pipeline;

  //   assign instruction_mem_bus.addr = PC;
  //   assign instruction_mem_bus.read_en = advance_pipeline;
  //   assign fetched_IR = instruction_mem_bus.rdata;

  //   always_ff @(posedge clk) begin
  //     if (reset) begin
  //       PC <= '0;
  //     end else begin
  //       if (advance_pipeline) begin
  //         PC <= PC + 4;
  //       end
  //     end
  //   end

  //   always_comb begin
  //     if (decoder_out.valid && decoder_out.uop.is_branch) begin
  //       advance_pipeline = 1'b0;
  //     end else begin
  //       advance_pipeline = 1'b1;
  //     end
  //   end

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
  //       .fetched_IR(fetched_IR),
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

  //   LSU lsu (
  //       .clk(clk),
  //       .reset(reset),
  //       .stq_bus(stq_bus),
  //       .rf_write_bus(lsu_write_bus),
  //       .ldq_bus(ldq_bus),
  //       .mem_bus(data_mem_bus)
  //   );


endmodule : RISCV
