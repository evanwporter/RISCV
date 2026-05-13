import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_constants_pkg::*;

package riscv_decoder_types_pkg;
  /// R-type Instructions
  typedef enum logic [9:0] {
    /// Add
    /// rd = rs1 + rs2
    OP_ADD,

    /// Subtract
    /// rd = rs1 - rs2
    OP_SUB,

    /// XOR
    /// rd = rs1 ^ rs2
    OP_XOR,

    /// OR
    /// rd = rs1 | rs2
    OP_OR,

    /// AND
    /// rd = rs1 & rs2
    OP_AND,

    /// Shift Left Logical (SLL)
    /// rd = rs1 << rs2
    OP_SLL,

    /// Shift Right Logical (SRL)
    /// rd = rs1 >> rs2 (logical)
    OP_SRL,

    /// Shift Right Arithmetic (SRA)
    /// rd = rs1 >> rs2 (arithmetic) (msb extends)
    OP_SRA,

    /// Set Less Than (SLT)
    /// rd = (rs1 < rs2) ? 1 : 0 (signed)
    OP_SLT,

    /// Set Less Than Unsigned (SLTU)
    /// rd = (rs1 < rs2) ? 1 : 0 (unsigned) (zero extends)
    OP_SLTU
  } alu_op_t;

  typedef union packed {
    logic [31:7] raw;

    struct packed {
      logic [6:0]   _padding1;
      logical_reg_t rs2;
      logical_reg_t rs1;
      logic [2:0]   _padding0;
      logical_reg_t rd;
    } regs;

    struct packed {
      logic [6:0]   func7;
      logical_reg_t rs2;
      logical_reg_t rs1;
      logic [2:0]   func3;
      logical_reg_t rd;
    } r_type;

    struct packed {
      logic [11:0]  imm;
      logical_reg_t rs1;
      logic [2:0]   funct3;
      logical_reg_t rd;
    } i_type;

    struct packed {
      logic [6:0]   imm_hi;  // instr[31:25]
      logical_reg_t rs2;
      logical_reg_t rs1;
      logic [2:0]   funct3;
      logic [4:0]   imm_lo;  // instr[11:7]
    } s_type;

    struct packed {
      logic imm12;  // instr[31]
      logic [5:0] imm10_5;  // instr[30:25]
      logical_reg_t rs2;
      logical_reg_t rs1;
      logic [2:0] funct3;
      logic [3:0] imm4_1;  // instr[11:8]
      logic imm11;  // instr[7]
    } b_type;

    struct packed {
      logic [19:0]  imm31_12;  // instr[31:12]
      logical_reg_t rd;
    } u_type;

    struct packed {
      logic imm20;  // instr[31]
      logic [9:0] imm10_1;  // instr[30:21]
      logic imm11;  // instr[20]
      logic [7:0] imm19_12;  // instr[19:12]
      logical_reg_t rd;
    } j_type;
  } extra_t;

  typedef enum logic [6:0] {
    OP_R_TYPE = 7'b0110011,
    OP_B_TYPE = 7'b1100011,
    OP_S_TYPE = 7'b0100011,
    OP_I_JALR_TYPE = 7'b1100111,
    OP_I_LOAD_TYPE = 7'b0000011,
    OP_I_ALU_TYPE = 7'b0010011,
    OP_I_FENCE_TYPE = 7'b0001111,
    OP_I_ECALL_TYPE = 7'b1110011,
    OP_U_LUI_TYPE = 7'b0110111,
    OP_U_AUIPC_TYPE = 7'b0010111,
    OP_J_TYPE = 7'b1101111
  } opcode_t;

  typedef struct packed {
    extra_t  extra;
    opcode_t opcode;
  } decoded_word_t;

  typedef enum logic [2:0] {
    IMM_NONE,

    /// I-type
    IMM_I,

    /// S-type (stores)
    IMM_S,

    /// B-type (branches)
    IMM_B,

    /// U-type
    IMM_U,

    /// J-type
    IMM_J

  } imm_kind_t;

  typedef enum logic [2:0] {
    BRANCH_EQ  = 3'h0,
    BRANCH_NEQ = 3'h1,
    BRANCH_LT  = 3'h4,
    BRANCH_GE  = 3'h5,
    BRANCH_LTU = 3'h6,
    BRANCH_GEU = 3'h7
  } branch_kind_t;

  typedef struct packed {
    // Identity
    decoded_word_t inst;
    word_t pc;

    // Registers (architectural)
    logical_reg_t rd;
    logical_reg_t rs1;
    logical_reg_t rs2;

    logic has_rd;
    logic has_rs1;
    logic has_rs2;

    // Registers (physical)
    physical_reg_t pdst;
    physical_reg_t prs1;
    physical_reg_t prs2;

    word_t dest_value;

    logic prs1_ready;
    logic prs2_ready;

    alu_op_t alu_op;

    branch_kind_t branch_op;

    // Immediate
    imm_kind_t   imm_kind;
    logic [31:0] imm;

    // Classification
    logic is_alu;
    logic is_branch;
    logic is_jump;
    logic is_load;
    logic is_store;
    logic is_ecall;

    logic  predicted_taken;
    word_t predicted_target;

    // OoO bookkeeping
    logic [ROB_IDX_WIDTH-1:0] rob_idx;

  } uop_t;

  /// TODO: move to different package
  typedef struct packed {
    logic valid;

    physical_reg_t Pd_new;

    physical_reg_t Pd_old;

    physical_reg_t Ps1;

    physical_reg_t Ps2;

    logic Ps1_ready;

    logic Ps2_ready;

    uop_t uop;

    logic [STQ_IDX_WIDTH-1:0] stq_idx;
    logic [LDQ_IDX_WIDTH-1:0] ldq_idx;

    logic [ROB_IDX_WIDTH-1:0] rob_idx;

  } rat_output_t;

  typedef struct packed {
    word_t IR;
    addr_t PC;
    logic  valid;
  } decoder_input_t;

  typedef struct packed {
    logic valid;
    uop_t uop;
    logic [STQ_IDX_WIDTH-1:0] stq_idx;
    logic [LDQ_IDX_WIDTH-1:0] ldq_idx;
  } decoder_output_t;

endpackage : riscv_decoder_types_pkg
