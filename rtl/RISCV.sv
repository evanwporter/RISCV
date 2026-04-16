import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_rob_types_pkg::*;
import constants_pkg::*;
import riscv_decoder_types_pkg::*;

module RISCV (
    input logic clk,
    input logic reset
);
  // word_t [31:0] reg_file;

  // decoded_word_t decoded_word;
  // rat_output_t rat_out;
  // word_t fetched_IR;

  // logic [NUM_PHYSICAL_REGS-1:0] freed_list;

  // // Dispatcher -> IQ/ROB
  // logic in_valid;

  // IssueQueue_if iq_if ();
  // ReorderBuffer_if rob_if ();
  // Writeback_if wb_bus ();
  // ALU_if alu_bus ();

  // Decoder decoder (
  //     .clk(clk),
  //     .reset(reset),
  //     .fetched_IR(fetched_IR),
  //     .word(decoded_word)
  // );

  // RegisterRenamer renamer (
  //     .clk(clk),
  //     .reset(reset),
  //     .word(decoded_word),
  //     .freed_list(freed_list),
  //     .rat_out(rat_out),
  //     .advance_pipeline(in_valid),
  //     .wb_bus(wb_bus)
  // );

  // Dispatcher dispatcher (
  //     .clk(clk),
  //     .reset(reset),
  //     .iq_bus(iq_if),
  //     .rob_bus(rob_if),
  //     .rat_out(rat_out)
  // );

  // IssueQueue iq (
  //     .clk(clk),
  //     .reset(reset),
  //     .bus(iq_if),
  //     .wb_bus(wb_bus)
  // );

  // ReorderBuffer rob (
  //     .clk(clk),
  //     .reset(reset),
  //     .wb_bus(wb_bus),
  //     .bus(rob_if)
  // );

  // ALU alu (.bus(alu_bus));

  // // Writeback
  // always_ff @(posedge clk) begin
  //   if (reset) begin
  //     // Initialize register file to 0 on reset
  //     for (int i = 0; i < 32; i++) begin
  //       reg_file[i] <= '0;
  //     end
  //   end else begin
  //     // Writeback logic: write results back to the register file
  //     if (wb_bus.valid) begin
  //       reg_file[wb_bus.pdst] <= alu_bus.out;
  //     end
  //   end
  // end

  // always_ff @(posedge clk) begin
  //   if (reset) begin
  //     fetched_IR <= '0;
  //   end else begin
  //     // For simplicity, we can just fetch a new instruction every cycle
  //     // In a real implementation, this would be more complex and involve an instruction memory
  //     fetched_IR <= fetched_IR + 4; // Simulate fetching the next instruction (assuming 4-byte instructions)
  //   end
  // end

endmodule : RISCV
