import riscv_types_pkg::*;
import riscv_constants_pkg::*;
import riscv_regs_types_pkg::*;

package riscv_renamer_types_pkg;

  typedef struct packed {
    physical_reg_t [31:0] RAT;
    free_list_t free_list;
    logic valid;
  } checkpoint_t;

  typedef struct packed {
    logic valid;
    physical_reg_t idx;
  } next_free_t;

endpackage : riscv_renamer_types_pkg
