import riscv_regs_types_pkg::*;
import riscv_decoder_types_pkg::*;

module Dispatcher (
    IssueQueue_if.Dispatcher_Side alu_iq_bus,
    IssueQueue_if.Dispatcher_Side mem_iq_bus,
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
    alu_iq_bus.push = 0;
    alu_iq_bus.push_entry = '0;

    if (rat_out.advance_pipeline) begin
      alu_iq_bus.push = 1;

      alu_iq_bus.push_entry.valid = 1;
      alu_iq_bus.push_entry.pdst = rat_out.Pd_new;

      alu_iq_bus.push_entry.prs1 = rat_out.Ps1;
      alu_iq_bus.push_entry.prs2 = rat_out.Ps2;

      alu_iq_bus.push_entry.prs1_ready = rat_out.Ps1_ready;
      alu_iq_bus.push_entry.prs2_ready = rat_out.Ps2_ready;

      alu_iq_bus.push_entry.uop = rat_out.uop;

      alu_iq_bus.push_entry.rob_idx = rob_bus.tail_ptr;
    end
  end

endmodule : Dispatcher
