import riscv_regs_types_pkg::*;
import riscv_decoder_types_pkg::*;

module ExecutionUnit (
    input logic clk,
    input logic reset,

    IssueQueue_if.Execution_Side iq_bus,
    RF_Read_if.User_side a_bus,
    RF_Read_if.User_side b_bus,
    RF_Write_if.User_side write_bus
);

  ALU_if alu_bus ();

  ALU alu (.bus(alu_bus));

  uop_t uop;
  assign uop = iq_bus.issue_entry.uop;

  always_comb begin
    alu_bus.op_a = 32'b0;
    alu_bus.op_b = 32'b0;
    alu_bus.opcode = OP_ADD;

    a_bus.en = 1'b0;
    a_bus.addr = P0;

    b_bus.en = 1'b0;
    b_bus.addr = P0;

    if (iq_bus.issue_valid) begin
      alu_bus.opcode = uop.alu_op;

      a_bus.en = 1'b1;
      a_bus.addr = iq_bus.issue_entry.prs1;
      alu_bus.op_a = a_bus.data;

      b_bus.en = 1'b1;
      b_bus.addr = iq_bus.issue_entry.prs2;
      alu_bus.op_b = b_bus.data;
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
    end else begin
      write_bus.en <= 1'b0;
      if (iq_bus.issue_valid) begin
        write_bus.en <= 1'b1;

        write_bus.rob_idx <= iq_bus.issue_entry.rob_idx;
        write_bus.addr <= iq_bus.issue_entry.pdst;
        write_bus.data <= alu_bus.out;
      end
    end
  end
endmodule
