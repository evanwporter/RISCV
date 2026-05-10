import riscv_regs_types_pkg::*;
import riscv_decoder_types_pkg::*;

`include "riscv/util.svh"

module Dispatcher (
    IssueQueue_if.Dispatcher_Side alu_iq_bus,
    IssueQueue_if.Dispatcher_Side mem_iq_bus,
    ReorderBuffer_if.Dispatcher_Side rob_bus,

    input rat_output_t rat_out
);

  always_comb begin
    if (rat_out.advance_pipeline) begin
      `RV_ASSERT(rat_out.rob_idx == rob_bus.tail_ptr,
                 ("Error: ROB tail pointer and RAT output ROB index should match, but got tail pointer %0d and RAT output ROB index %0d",
       rob_bus.tail_ptr,
       rat_out.rob_idx)
    );
    end
  end

  // ROB entry construction
  always_comb begin
    rob_bus.push = 0;
    rob_bus.push_entry = '0;

    if (rat_out.advance_pipeline) begin
      rob_bus.push = 1;
      rob_bus.push_entry.valid = 1;
      rob_bus.push_entry.busy = 0;  // Ecall doesn't need to wait for execution to commit
      rob_bus.push_entry.exception = 0;
      rob_bus.push_entry.old_dest = rat_out.Pd_old;
      rob_bus.push_entry.new_dest = rat_out.Pd_new;
      rob_bus.push_entry.stq_idx_valid = rat_out.uop.is_store;
      rob_bus.push_entry.stq_idx = rat_out.stq_idx;
      rob_bus.push_entry.PC = rat_out.uop.pc;
      rob_bus.push_entry.is_branch = rat_out.uop.is_branch || rat_out.uop.is_jump;
      rob_bus.push_entry.rd = rat_out.uop.rd;
      rob_bus.push_entry.has_rd = rat_out.uop.has_rd;
      rob_bus.push_entry.rob_idx = rob_bus.tail_ptr;

      if (rat_out.uop.is_ecall) begin
        rob_bus.push_entry.is_ecall = 1;
        rob_bus.push_entry.busy = 1;
      end
    end
  end

  // ALU IQ entry construction
  always_comb begin
    alu_iq_bus.push = 0;
    alu_iq_bus.push_entry = '0;

    if (rat_out.advance_pipeline && 
       (rat_out.uop.is_alu || 
        rat_out.uop.is_branch || 
        rat_out.uop.is_jump || 
        rat_out.uop.is_ecall)) begin

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

  // Memory IQ entry construction
  always_comb begin
    mem_iq_bus.push = 0;
    mem_iq_bus.push_entry = '0;

    if (rat_out.advance_pipeline && (rat_out.uop.is_store || rat_out.uop.is_load)) begin
      mem_iq_bus.push = 1;

      mem_iq_bus.push_entry.valid = 1;
      mem_iq_bus.push_entry.pdst = rat_out.Pd_new;

      mem_iq_bus.push_entry.prs1 = rat_out.Ps1;
      mem_iq_bus.push_entry.prs2 = rat_out.Ps2;

      mem_iq_bus.push_entry.prs1_ready = rat_out.Ps1_ready;
      mem_iq_bus.push_entry.prs2_ready = rat_out.Ps2_ready;

      mem_iq_bus.push_entry.uop = rat_out.uop;

      mem_iq_bus.push_entry.rob_idx = rob_bus.tail_ptr;

      mem_iq_bus.push_entry.stq_idx = rat_out.stq_idx;
      mem_iq_bus.push_entry.ldq_idx = rat_out.ldq_idx;
    end
  end

endmodule : Dispatcher
