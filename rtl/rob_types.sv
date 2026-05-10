import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_lsu_types_pkg::*;
import riscv_constants_pkg::*;

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
    logic [STQ_IDX_WIDTH-1:0] stq_idx;

    logic [ROB_IDX_WIDTH-1:0] rob_idx;

    addr_t PC;

    branch_info_t branch_info;

    logic is_branch;

    logic is_ecall;

    logical_reg_t rd;

    logic has_rd;

  } ROB_entry_t;

  typedef struct packed {
    logic executed_op_valid;
    logic [ROB_IDX_WIDTH-1:0] executed_op_rob_idx;
  } executed_op_t;

endpackage : riscv_rob_types_pkg
