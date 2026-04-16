import riscv_types_pkg::*;
import riscv_decoder_types_pkg::*;

module Decoder (
    input logic  clk,
    input logic  reset,
    input logic  advance_pipeline,
    input word_t fetched_IR,

    output uop_t uop,
    output logic valid
);

  decoded_word_t decoded_IR;

  // Pipeline register
  always_ff @(posedge clk) begin
    if (reset) begin
      decoded_IR <= '0;
      valid <= 1'b0;
    end else begin
      valid <= 1'b0;
      if (advance_pipeline) begin
        decoded_IR <= fetched_IR;
        valid <= 1'b1;
      end
    end
  end

  // Decode logic
  always_comb begin
    // Default everything
    uop      = '0;

    // Identity
    uop.inst = decoded_IR;
    uop.pc   = '0;  // fill later when PC available

    // Extract common fields

    uop.rd   = decoded_IR.extra.regs.rd;
    uop.rs1  = decoded_IR.extra.regs.rs1;
    uop.rs2  = decoded_IR.extra.regs.rs2;

    // Opcode decode
    unique case (decoded_IR.opcode)

      // R-TYPE (ALU)
      OP_R_TYPE: begin
        uop.has_rd   = 1'b1;
        uop.has_rs1  = 1'b1;
        uop.has_rs2  = 1'b1;

        uop.is_alu   = 1'b1;
        uop.imm_kind = IMM_I;

        case ({
          decoded_IR.extra.r_type.func3, decoded_IR.extra.r_type.func7
        })

          {3'b000, 7'b0000000} : uop.alu_op = OP_ADD;
          {3'b000, 7'b0100000} : uop.alu_op = OP_SUB;

          {3'b100, 7'b0000000} : uop.alu_op = OP_XOR;
          {3'b110, 7'b0000000} : uop.alu_op = OP_OR;
          {3'b111, 7'b0000000} : uop.alu_op = OP_AND;

          {3'b001, 7'b0000000} : uop.alu_op = OP_SLL;

          {3'b101, 7'b0000000} : uop.alu_op = OP_SRL;
          {3'b101, 7'b0100000} : uop.alu_op = OP_SRA;

          {3'b010, 7'b0000000} : uop.alu_op = OP_SLT;
          {3'b011, 7'b0000000} : uop.alu_op = OP_SLTU;

          default: uop.alu_op = OP_ADD;

        endcase
      end

      // I-TYPE ALU
      OP_I_ALU_TYPE: begin
        uop.has_rd = 1'b1;
        uop.has_rs1 = 1'b1;

        uop.is_alu = 1'b1;
        uop.imm = {{20{decoded_IR[31]}}, decoded_IR[31:20]};
        uop.imm_kind = IMM_I;

        case (decoded_IR.extra.i_type.funct3)

          3'b000: uop.alu_op = OP_ADD;  // ADDI
          3'b100: uop.alu_op = OP_XOR;
          3'b110: uop.alu_op = OP_OR;
          3'b111: uop.alu_op = OP_AND;

          3'b010: uop.alu_op = OP_SLT;
          3'b011: uop.alu_op = OP_SLTU;

          3'b001: uop.alu_op = OP_SLL;

          3'b101: begin
            if (decoded_IR.extra.i_type.imm[11:5] == 7'b0000000) uop.alu_op = OP_SRL;
            else uop.alu_op = OP_SRA;
          end

          default: uop.alu_op = OP_ADD;

        endcase
      end

      // LOAD
      OP_I_LOAD_TYPE: begin
        uop.has_rd = 1'b1;
        uop.has_rs1 = 1'b1;

        uop.is_load = 1'b1;
        uop.imm = {{20{decoded_IR[31]}}, decoded_IR[31:20]};
        uop.imm_kind = IMM_I;
      end

      // STORE
      OP_S_TYPE: begin
        uop.has_rs1 = 1'b1;
        uop.has_rs2 = 1'b1;

        uop.is_store = 1'b1;
        uop.imm = {{20{decoded_IR[31]}}, decoded_IR[31:25], decoded_IR[11:7]};
        uop.imm_kind = IMM_S;
      end

      // BRANCH
      OP_B_TYPE: begin
        uop.has_rs1 = 1'b1;
        uop.has_rs2 = 1'b1;

        uop.is_branch = 1'b1;
        uop.imm = {
          {19{decoded_IR[31]}},
          decoded_IR[31],
          decoded_IR[7],
          decoded_IR[30:25],
          decoded_IR[11:8],
          1'b0
        };
        uop.imm_kind = IMM_B;
      end

      // JAL
      OP_J_TYPE: begin
        uop.has_rd = 1'b1;
        uop.is_jump = 1'b1;
        uop.imm = {
          {11{decoded_IR[31]}},
          decoded_IR[31],
          decoded_IR[19:12],
          decoded_IR[20],
          decoded_IR[30:21],
          1'b0
        };
        uop.imm_kind = IMM_J;
      end

      // JALR
      OP_I_JALR_TYPE: begin
        uop.has_rd = 1'b1;
        uop.has_rs1 = 1'b1;

        uop.is_jump = 1'b1;
        uop.imm = {{20{decoded_IR[31]}}, decoded_IR[31:25], decoded_IR[11:7]};
        uop.imm_kind = IMM_I;
      end

      // U-TYPE
      OP_U_LUI_TYPE, OP_U_AUIPC_TYPE: begin
        uop.has_rd = 1'b1;
        uop.imm = {decoded_IR[31:12], 12'b0};
        uop.imm_kind = IMM_U;
      end

      OP_I_FENCE_TYPE, OP_I_ECALL_TYPE: begin
        // TODO
      end

    endcase
  end

endmodule
