import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_constants_pkg::*;

package riscv_lsu_types_pkg;

  typedef struct packed {
    /// Entry has been allocated by the decoder
    logic  valid;
    logic  addr_valid;
    addr_t addr;

    physical_reg_t pdst;

    /// Load has completed
    logic executed;

    /// Waiting on older store data
    logic sleeping;

    /// Result available
    logic succeeded;
    logic from_forward;  // result came from store forwarding
    logic from_mem;  // result came from memory

    /// Older stores this load depends on
    logic [STQ_WIDTH-1:0] st_dep_mask;

    logic [ROB_IDX_WIDTH-1:0] rob_idx;
    addr_t PC;
  } ldq_entry_t;

  typedef struct packed {
    /// Entry has been allocated by the decoder
    logic valid;

    /// Whether the store has been committed (passed the ROB head)
    logic committed;

    /// Whether the store has a valid address
    logic addr_valid;

    /// Calculated address for the store
    addr_t addr;

    /// Whether the store has valid data
    logic data_valid;

    /// Data to store
    word_t data;
  } stq_entry_t;

  typedef enum {
    BYTE,
    HALFWORD,
    WORD
  } size_t;

endpackage : riscv_lsu_types_pkg
