import riscv_regs_types_pkg::*;
import riscv_decoder_types_pkg::*;

`include "riscv/util.svh"

module Dispatcher (
    IssueQueue_if.Dispatcher_Side alu_iq_bus,
    IssueQueue_if.Dispatcher_Side mem_iq_bus,
    ReorderBuffer_if.Dispatcher_Side rob_bus,

    input rat_output_t rat_out,

    output logic dispatcher_fire
);

  /// Current micro-op.
  uop_t uop;
  assign uop = rat_out.uop;

  /// Whether we should dispatch/push to the ALU IQ.
  wire alu_iq_dispatch = uop.is_alu || uop.is_branch || uop.is_jump || uop.is_ecall;

  /// Whether we should dispatch/push to the Memory IQ.
  wire mem_iq_dispatch = uop.is_load || uop.is_store;

  /// Whether one of the IQs is ready to accept a new entry. Or if we aren't dispatching 
  /// to either IQ, then we're ready regardless.
  wire iq_ready = (!alu_iq_dispatch || !alu_iq_bus.full) && (!mem_iq_dispatch || !mem_iq_bus.full);

  /// We either to push to the `IQs` and `ROB`, or we stall the pipeline. All or nothing.
  wire dispatch_ready = rat_out.valid && !rob_bus.full && iq_ready;

  assign dispatcher_fire = rat_out.valid && dispatch_ready;

  // ROB entry construction
  always_comb begin
    rob_bus.push = 0;
    rob_bus.push_entry = '0;

    if (dispatcher_fire) begin
      rob_bus.push = 1;
      rob_bus.push_entry.valid = 1;
      rob_bus.push_entry.busy = 0;
      rob_bus.push_entry.exception = 0;
      rob_bus.push_entry.old_dest = rat_out.Pd_old;
      rob_bus.push_entry.new_dest = rat_out.Pd_new;
      rob_bus.push_entry.stq_idx_valid = uop.is_store;
      rob_bus.push_entry.stq_idx = rat_out.stq_idx;
      rob_bus.push_entry.PC = uop.pc;
      rob_bus.push_entry.is_branch = uop.is_branch || uop.is_jump;
      rob_bus.push_entry.rd = uop.rd;
      rob_bus.push_entry.has_rd = uop.has_rd;
      rob_bus.push_entry.rob_idx = rob_bus.tail_ptr;

      if (uop.is_ecall) begin
        rob_bus.push_entry.is_ecall = 1;
        rob_bus.push_entry.busy = 1;
      end
    end
  end

  // ALU IQ entry construction
  always_comb begin
    alu_iq_bus.push = 0;
    alu_iq_bus.push_entry = '0;

    if (dispatcher_fire && alu_iq_dispatch) begin

      alu_iq_bus.push = 1;

      alu_iq_bus.push_entry.valid = 1;
      alu_iq_bus.push_entry.pdst = rat_out.Pd_new;

      alu_iq_bus.push_entry.prs1 = rat_out.Ps1;
      alu_iq_bus.push_entry.prs2 = rat_out.Ps2;

      alu_iq_bus.push_entry.prs1_ready = rat_out.Ps1_ready;
      alu_iq_bus.push_entry.prs2_ready = rat_out.Ps2_ready;

      alu_iq_bus.push_entry.uop = uop;

      alu_iq_bus.push_entry.rob_idx = rob_bus.tail_ptr;
    end
  end

  // Memory IQ entry construction
  always_comb begin
    mem_iq_bus.push = 0;
    mem_iq_bus.push_entry = '0;

    if (dispatcher_fire && mem_iq_dispatch) begin
      mem_iq_bus.push = 1;

      mem_iq_bus.push_entry.valid = 1;
      mem_iq_bus.push_entry.pdst = rat_out.Pd_new;

      mem_iq_bus.push_entry.prs1 = rat_out.Ps1;
      mem_iq_bus.push_entry.prs2 = rat_out.Ps2;

      mem_iq_bus.push_entry.prs1_ready = rat_out.Ps1_ready;
      mem_iq_bus.push_entry.prs2_ready = rat_out.Ps2_ready;

      mem_iq_bus.push_entry.uop = uop;

      mem_iq_bus.push_entry.rob_idx = rob_bus.tail_ptr;

      mem_iq_bus.push_entry.stq_idx = rat_out.stq_idx;
      mem_iq_bus.push_entry.ldq_idx = rat_out.ldq_idx;
    end
  end

  always_comb begin
    if (rat_out.valid) begin
      `RV_ASSERT(rat_out.rob_idx == rob_bus.tail_ptr,
                 ("Error: ROB tail pointer and RAT output ROB index should match, but got tail pointer %0d and RAT output ROB index %0d",
       rob_bus.tail_ptr,
       rat_out.rob_idx)
    );
    end
  end

  always_comb begin
    `RV_ASSERT(!(alu_iq_dispatch && mem_iq_dispatch),
               ("Instruction cannot dispatch to both ALU IQ and MEM IQ"))
  end

endmodule : Dispatcher
