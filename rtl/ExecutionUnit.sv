import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_decoder_types_pkg::*;

module ExecutionUnit (
    input logic clk,
    input logic reset,

    input flush_t flush_info,

    IssueQueue_if.Execution_Side alu_iq_bus,
    IssueQueue_if.Execution_Side mem_iq_bus,

    ReorderBuffer_if.Execution_Side rob_bus,

    output branch_info_t branch_info,

    STQ_if.Execution_side stq_bus,
    LDQ_if.Execution_side ldq_bus,

    RF_Read_if.User_side  alu_a_bus,
    RF_Read_if.User_side  alu_b_bus,
    RF_Write_if.User_side alu_write_bus,

    RF_Read_if.User_side mem_a_bus,
    RF_Read_if.User_side mem_b_bus
);

  ALU_if alu_bus ();
  ALU alu (.bus(alu_bus));

  AGU_if agu_bus ();
  AGU agu (.bus(agu_bus));

  uop_t alu_uop;
  assign alu_uop = alu_iq_bus.issue_entry.uop;

  uop_t mem_uop;
  assign mem_uop = mem_iq_bus.issue_entry.uop;

  always_comb begin
    alu_bus.op_a   = 32'b0;
    alu_bus.op_b   = 32'b0;
    alu_bus.opcode = OP_ADD;

    alu_a_bus.en   = 1'b0;
    alu_a_bus.addr = P0;

    alu_b_bus.en   = 1'b0;
    alu_b_bus.addr = P0;

    if (alu_iq_bus.issue_valid) begin
      alu_bus.opcode = alu_uop.alu_op;

      alu_a_bus.en   = 1'b1;
      alu_a_bus.addr = alu_iq_bus.issue_entry.prs1;
      alu_bus.op_a   = alu_a_bus.data;

      alu_b_bus.en   = 1'b1;
      alu_b_bus.addr = alu_iq_bus.issue_entry.prs2;
      alu_bus.op_b   = alu_b_bus.data;

      case (alu_uop.imm_kind)
        IMM_I: begin
          alu_bus.op_b = alu_uop.imm;
        end

        IMM_U: begin
          alu_bus.op_b = alu_uop.imm;

          if (alu_uop.inst.opcode == OP_U_AUIPC_TYPE) alu_bus.op_a = alu_uop.pc;
          else alu_bus.op_a = 32'b0;  // LUI
        end

        default: begin
          // R-type uses register operands
        end
      endcase
    end
  end

  wire  alu_exec = alu_iq_bus.issue_valid && alu_uop.is_alu;
  wire  branch_exec = alu_iq_bus.issue_valid && alu_uop.is_branch;

  logic branch_taken;

  wire  mispredict = branch_exec && branch_taken;

  always_comb begin
    case (alu_uop.branch_op)
      BRANCH_EQ: branch_taken = (alu_bus.op_a == alu_bus.op_b);
      BRANCH_NEQ: branch_taken = (alu_bus.op_a != alu_bus.op_b);
      // TODO: extend
      default: branch_taken = 1'b0;
    endcase
  end

  always_ff @(posedge clk) begin
    if (reset) begin
    end else begin
      alu_write_bus.en <= 1'b0;
      alu_write_bus.rob_idx <= '0;
      alu_write_bus.addr <= P0;
      alu_write_bus.data <= 32'b0;

      if (!flush_info.valid && alu_exec) begin
        alu_write_bus.en <= 1'b1;  // don't writeback if destination is P0 (zero reg)

        // assert (alu_iq_bus.issue_entry.pdst != P0)
        // else $error("Error: ALU is trying to write to P0, which should never happen");

        alu_write_bus.rob_idx <= alu_iq_bus.issue_entry.rob_idx;
        alu_write_bus.PC <= alu_uop.pc;
        alu_write_bus.addr <= alu_iq_bus.issue_entry.pdst;
        alu_write_bus.data <= alu_bus.out;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      branch_info <= '0;

    end else begin
      branch_info <= '0;

      if (alu_write_bus.en) begin
        $display("ALU_WB PC=%0d pdst=P%0d data=%08h rob=%0d", alu_write_bus.PC, alu_write_bus.addr,
                 alu_write_bus.data, alu_write_bus.rob_idx);
      end

      if (branch_exec) begin
        $display("BRANCH PC=%0d prs1=%0d val1=%h prs2=%0d val2=%h taken=%0b target=%0d", alu_uop.pc,
                 alu_iq_bus.issue_entry.prs1, alu_bus.op_a, alu_iq_bus.issue_entry.prs2,
                 alu_bus.op_b, branch_taken, alu_uop.pc + alu_uop.imm);
      end

      if (!flush_info.valid && branch_exec) begin
        branch_info.valid  <= 1'b1;
        branch_info.target <= alu_uop.pc + alu_uop.imm;

        $display("Branch executed at PC=%0d: imm=%0d", alu_uop.pc, alu_uop.imm);

        branch_info.mispredict <= mispredict;
        branch_info.rob_idx <= alu_iq_bus.issue_entry.rob_idx;

        branch_info.taken <= branch_taken;
      end
    end
  end

  always_comb begin
    // Defaults
    agu_bus.base = '0;
    agu_bus.offset = '0;

    stq_bus.write_addr = 1'b0;
    stq_bus.write_addr_idx = '0;
    stq_bus.write_addr_value = '0;

    stq_bus.write_data = 1'b0;
    stq_bus.write_data_idx = '0;
    stq_bus.write_data_value = '0;

    ldq_bus.write_addr = 1'b0;
    ldq_bus.write_addr_idx = '0;
    ldq_bus.write_addr_value = '0;

    mem_a_bus.en = 1'b0;
    mem_a_bus.addr = P0;

    mem_b_bus.en = 1'b0;
    mem_b_bus.addr = P0;

    if (mem_iq_bus.issue_valid) begin
      // Common: base = rs1
      mem_a_bus.en   = 1'b1;
      mem_a_bus.addr = mem_iq_bus.issue_entry.prs1;
      agu_bus.base   = mem_a_bus.data;

      agu_bus.offset = mem_uop.imm;

      if (mem_uop.is_store) begin
        // Address path (uopSTA)
        stq_bus.write_addr = 1'b1;
        stq_bus.write_addr_idx = mem_iq_bus.issue_entry.stq_idx;
        stq_bus.write_addr_value = agu_bus.addr;

        // Data path (uopSTD)
        mem_b_bus.en = 1'b1;
        mem_b_bus.addr = mem_iq_bus.issue_entry.prs2;

        stq_bus.write_data = 1'b1;
        stq_bus.write_data_idx = mem_iq_bus.issue_entry.stq_idx;
        stq_bus.write_data_value = mem_b_bus.data;
      end else if (mem_uop.is_load) begin
        ldq_bus.write_addr = 1'b1;
        ldq_bus.write_addr_idx = mem_iq_bus.issue_entry.ldq_idx;
        ldq_bus.write_addr_value = agu_bus.addr;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      rob_bus.ALU_executed_op <= '0;
      rob_bus.STR_executed_op <= '0;
    end else begin
      rob_bus.ALU_executed_op <= '0;
      rob_bus.STR_executed_op <= '0;

      // ALU completion
      if (alu_iq_bus.issue_valid) begin
        rob_bus.ALU_executed_op.executed_op_valid   <= 1'b1;
        rob_bus.ALU_executed_op.executed_op_rob_idx <= alu_iq_bus.issue_entry.rob_idx;
      end

      // Load/Store completion
      if (mem_iq_bus.issue_valid && (mem_uop.is_store || mem_uop.is_load)) begin
        if (mem_uop.is_store) begin
          rob_bus.STR_executed_op.executed_op_valid   <= 1'b1;
          rob_bus.STR_executed_op.executed_op_rob_idx <= mem_iq_bus.issue_entry.rob_idx;
        end else if (mem_uop.is_load) begin
          rob_bus.STR_executed_op.executed_op_valid   <= 1'b1;
          rob_bus.STR_executed_op.executed_op_rob_idx <= mem_iq_bus.issue_entry.rob_idx;
        end
      end
    end
  end
endmodule
