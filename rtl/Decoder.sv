import riscv_types_pkg::*;
import riscv_decoder_types_pkg::*;
import riscv_regs_types_pkg::*;

module Decoder (
    input logic clk,
    input logic reset,
    input logic advance_pipeline,
    input logic flush,

    input decoder_input_t decoder_in,

    STQ_if.Decoder_side stq_bus,
    LDQ_if.Decoder_side ldq_bus,

    output decoder_output_t decoder_out
);

  decoded_word_t decoded_IR;
  assign decoded_IR = decoder_in.IR;

  uop_t uop_next;

  // Pipeline register
  always_ff @(posedge clk) begin
    if (reset || flush) begin
      decoder_out  <= '0;
      stq_bus.push <= 1'b0;
      ldq_bus.push <= 1'b0;
    end else begin
      // decoder_out.valid <= 1'b0;
      stq_bus.push <= 1'b0;
      ldq_bus.push <= 1'b0;
      if (advance_pipeline) begin
        decoder_out.uop <= uop_next;
        decoder_out.valid <= uop_next.is_alu ||
                             uop_next.is_load ||
                             uop_next.is_store ||
                             uop_next.is_branch ||
                             uop_next.is_jump;

        if (decoded_IR.opcode == OP_S_TYPE) begin
          stq_bus.push <= 1'b1;
          decoder_out.stq_idx <= stq_bus.tail_idx;
        end else if (decoded_IR.opcode == OP_I_LOAD_TYPE) begin
          ldq_bus.push <= 1'b1;
          decoder_out.ldq_idx <= ldq_bus.tail_idx;
        end
      end
    end
  end

  // Decode logic
  always_comb begin
    uop_next = '0;

    // Identity
    uop_next.inst = decoded_IR;
    uop_next.pc = decoder_in.PC;

    // Extract common fields
    uop_next.rd = decoded_IR.extra.regs.rd;
    uop_next.rs1 = decoded_IR.extra.regs.rs1;
    uop_next.rs2 = decoded_IR.extra.regs.rs2;

    // Opcode decode
    unique case (decoded_IR.opcode)

      // R-TYPE (ALU)
      OP_R_TYPE: begin
        uop_next.has_rd   = 1'b1;
        uop_next.has_rs1  = 1'b1;
        uop_next.has_rs2  = 1'b1;

        uop_next.is_alu   = 1'b1;
        uop_next.imm_kind = IMM_NONE;

        case ({
          decoded_IR.extra.r_type.func3, decoded_IR.extra.r_type.func7
        })

          {3'b000, 7'b0000000} : uop_next.alu_op = OP_ADD;
          {3'b000, 7'b0100000} : uop_next.alu_op = OP_SUB;

          {3'b100, 7'b0000000} : uop_next.alu_op = OP_XOR;
          {3'b110, 7'b0000000} : uop_next.alu_op = OP_OR;
          {3'b111, 7'b0000000} : uop_next.alu_op = OP_AND;

          {3'b001, 7'b0000000} : uop_next.alu_op = OP_SLL;

          {3'b101, 7'b0000000} : uop_next.alu_op = OP_SRL;
          {3'b101, 7'b0100000} : uop_next.alu_op = OP_SRA;

          {3'b010, 7'b0000000} : uop_next.alu_op = OP_SLT;
          {3'b011, 7'b0000000} : uop_next.alu_op = OP_SLTU;

          default: uop_next.alu_op = OP_ADD;

        endcase
      end

      // I-TYPE ALU
      OP_I_ALU_TYPE: begin
        uop_next.has_rd = 1'b1;
        uop_next.has_rs1 = 1'b1;

        uop_next.is_alu = 1'b1;
        uop_next.imm = {{20{decoded_IR[31]}}, decoded_IR.extra.i_type.imm};
        uop_next.imm_kind = IMM_I;

        case (decoded_IR.extra.i_type.funct3)

          3'b000: uop_next.alu_op = OP_ADD;  // ADDI
          3'b100: uop_next.alu_op = OP_XOR;
          3'b110: uop_next.alu_op = OP_OR;
          3'b111: uop_next.alu_op = OP_AND;

          3'b010: uop_next.alu_op = OP_SLT;
          3'b011: uop_next.alu_op = OP_SLTU;

          3'b001: uop_next.alu_op = OP_SLL;

          3'b101: begin
            if (decoded_IR.extra.i_type.imm[11:5] == 7'b0000000) uop_next.alu_op = OP_SRL;
            else uop_next.alu_op = OP_SRA;
          end

          default: uop_next.alu_op = OP_ADD;

        endcase
      end

      // LOAD
      OP_I_LOAD_TYPE: begin
        uop_next.has_rd = 1'b1;
        uop_next.has_rs1 = 1'b1;

        uop_next.is_load = 1'b1;
        uop_next.imm = {{20{decoded_IR[31]}}, decoded_IR[31:20]};
        uop_next.imm_kind = IMM_I;
      end

      // STORE
      OP_S_TYPE: begin
        uop_next.has_rs1 = 1'b1;
        uop_next.has_rs2 = 1'b1;

        uop_next.is_store = 1'b1;
        uop_next.imm = {{20{decoded_IR[31]}}, decoded_IR[31:25], decoded_IR[11:7]};
        uop_next.imm_kind = IMM_S;
      end

      // BRANCH
      OP_B_TYPE: begin
        uop_next.has_rs1 = 1'b1;
        uop_next.has_rs2 = 1'b1;

        uop_next.is_branch = 1'b1;
        uop_next.imm = {
          {19{decoded_IR[31]}},
          decoded_IR[31],
          decoded_IR[7],
          decoded_IR[30:25],
          decoded_IR[11:8],
          1'b0
        };
        uop_next.imm_kind = IMM_B;

        // TODO: Predict other branches. For now we will just predict not taken for branches.
        uop_next.predicted_taken = 1'b0;

        uop_next.branch_op = branch_kind_t'(decoded_IR.extra.b_type.funct3);
      end

      // JAL
      OP_J_TYPE: begin
        uop_next.has_rd = 1'b1;
        uop_next.is_jump = 1'b1;
        uop_next.imm = {
          {11{decoded_IR[31]}},
          decoded_IR[31],
          decoded_IR[19:12],
          decoded_IR[20],
          decoded_IR[30:21],
          1'b0
        };
        uop_next.imm_kind = IMM_J;
      end

      // JALR
      OP_I_JALR_TYPE: begin
        uop_next.has_rd = 1'b1;
        uop_next.has_rs1 = 1'b1;

        uop_next.is_jump = 1'b1;
        uop_next.imm = {{20{decoded_IR[31]}}, decoded_IR[31:20]};
        uop_next.imm_kind = IMM_I;
      end

      // U-TYPE
      OP_U_LUI_TYPE, OP_U_AUIPC_TYPE: begin
        uop_next.has_rd   = 1'b1;
        uop_next.is_alu   = 1'b1;
        uop_next.alu_op   = OP_ADD;
        uop_next.imm      = {decoded_IR[31:12], 12'b0};
        uop_next.imm_kind = IMM_U;
      end

      OP_I_FENCE_TYPE, OP_I_ECALL_TYPE: begin
        // TODO
        $warning("Decoder: Fence and ecall instructions are not fully implemented yet.");
      end

    endcase
  end

endmodule
