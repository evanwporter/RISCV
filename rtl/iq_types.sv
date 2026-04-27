import riscv_regs_types_pkg::*;
import riscv_decoder_types_pkg::*;
import riscv_constants_pkg::*;

package riscv_iq_types_pkg;

  /// IQ Entry provides everything needed to track an instruction from dispatch to commit
  typedef struct packed {
    /// TODO: technically this only needs to be within the IQ
    logic valid;

    /// Physical Destination Register
    physical_reg_t pdst;

    /// Physical Register Source #1
    physical_reg_t prs1;

    /// Physical Register Source #2
    physical_reg_t prs2;

    /// Physical Register Source #1 ready
    logic prs1_ready;

    /// Physical Register Source #2 ready
    logic prs2_ready;

    /// Micro-op for excecution
    uop_t uop;

    /// ROB tracking
    logic [ROB_IDX_WIDTH-1:0] rob_idx;

    logic [STQ_IDX_WIDTH-1:0] stq_idx;

    logic [LDQ_IDX_WIDTH-1:0] ldq_idx;

  } IQ_entry_t;
endpackage : riscv_iq_types_pkg
