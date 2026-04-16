import riscv_regs_types_pkg::*;
import riscv_rob_types_pkg::*;
import riscv_decoder_types_pkg::*;
import riscv_iq_types_pkg::*;

module Dispatcher #(
    parameter PTR_WIDTH = 5
) (
    input logic clk,
    input logic reset,

    IssueQueue_if.Dispatcher_Side iq_bus,
    ReorderBuffer_if.Dispatcher_Side rob_bus,

    input rat_output_t rat_out
);

  // ROB entry construction
  always_comb begin
    rob_bus.push = 0;
    rob_bus.push_entry = '0;

    if (rat_out.advance_pipeline && rat_out.Pd_new != P0) begin
      rob_bus.push = 1;
      rob_bus.push_entry.valid = 1;
      rob_bus.push_entry.busy = 1;
      rob_bus.push_entry.exception = 0;
      rob_bus.push_entry.old_dest = rat_out.Pd_old;
      rob_bus.push_entry.new_dest = rat_out.Pd_new;
    end
  end

  // IQ entry construction
  always_comb begin
    iq_bus.push = 0;
    iq_bus.push_entry = '0;

    if (rat_out.advance_pipeline) begin
      iq_bus.push = 1;

      iq_bus.push_entry.valid = 1;
      iq_bus.push_entry.pdst = rat_out.Pd_new;

      iq_bus.push_entry.prs1 = rat_out.Ps1;
      iq_bus.push_entry.prs2 = rat_out.Ps2;

      iq_bus.push_entry.prs1_ready = rat_out.Ps1_ready;
      iq_bus.push_entry.prs2_ready = rat_out.Ps2_ready;

      iq_bus.push_entry.uop = rat_out.uop;

      iq_bus.push_entry.rob_idx = rob_bus.tail_ptr;
    end
  end

endmodule : Dispatcher
