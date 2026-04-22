import riscv_regs_types_pkg::*;
import riscv_lsu_types_pkg::*;

package riscv_rob_types_pkg;

  typedef struct packed {
    logic valid;
    logic busy;
    logic exception;

    physical_reg_t old_dest;

    physical_reg_t new_dest;

    logic stq_idx_valid;

    /// The store queue index this instruction depends on
    /// if its a store.
    logic [1:0] stq_idx;

  } ROB_entry_t;

endpackage : riscv_rob_types_pkg
