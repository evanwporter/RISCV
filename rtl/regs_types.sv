import riscv_types_pkg::*;
import riscv_constants_pkg::*;

package riscv_regs_types_pkg;

  typedef logic [PHYSICAL_REG_IDX:0] physical_reg_t;

  physical_reg_t P0 = PHYSICAL_REG_IDX'(1'b0);

  typedef enum logic [4:0] {
    x0  = 5'd0,
    x1  = 5'd1,
    x2  = 5'd2,
    x3  = 5'd3,
    x4  = 5'd4,
    x5  = 5'd5,
    x6  = 5'd6,
    x7  = 5'd7,
    x8  = 5'd8,
    x9  = 5'd9,
    x10 = 5'd10,
    x11 = 5'd11,
    x12 = 5'd12,
    x13 = 5'd13,
    x14 = 5'd14,
    x15 = 5'd15,
    x16 = 5'd16,
    x17 = 5'd17,
    x18 = 5'd18,
    x19 = 5'd19,
    x20 = 5'd20,
    x21 = 5'd21,
    x22 = 5'd22,
    x23 = 5'd23,
    x24 = 5'd24,
    x25 = 5'd25,
    x26 = 5'd26,
    x27 = 5'd27,
    x28 = 5'd28,
    x29 = 5'd29,
    x30 = 5'd30,
    x31 = 5'd31
  } logical_reg_t;

  typedef logic [4:0] logical_reg_addr_t;

  typedef logic [5:0] physical_reg_addr_t;

  typedef struct packed {
    logic valid;

    /// Physical Register Destination (for writeback)
    /// Register getting written back to.
    physical_reg_t pdst;

    // For debugging purposes
    addr_t PC;

    logic [ROB_IDX_WIDTH-1:0] rob_idx;

    word_t data;

  } writeback_t;

  /// Stores the result of executing a branch instruction 
  typedef struct packed {
    logic  valid;
    logic  taken;
    addr_t target;

    logic mispredict;

    /// For misprediction recovery, we need to know which checkpoint to roll back to.
    logic [ROB_IDX_WIDTH-1:0] rob_idx;

    /// Mark this once/if we've flushed the branch (ie: modified the control flow)
    /// TODO: This is only needed for `oldest_branch_info` in RISCV.sv
    logic flushed;

    logic resolved;

  } branch_info_t;

  typedef struct packed {
    logic valid;
    logic [ROB_IDX_WIDTH-1:0] rob_idx;
  } flush_t;

  typedef logic [riscv_constants_pkg::NUM_PHYSICAL_REGS-1:0] free_list_t;
endpackage : riscv_regs_types_pkg
