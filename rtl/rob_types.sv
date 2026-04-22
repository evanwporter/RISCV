import riscv_regs_types_pkg::*;

package riscv_rob_types_pkg;

  typedef struct packed {
    logic valid;
    logic busy;
    logic exception;

    physical_reg_t old_dest;

    physical_reg_t new_dest;

  } ROB_entry_t;

endpackage : riscv_rob_types_pkg
