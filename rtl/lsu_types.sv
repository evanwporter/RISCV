import riscv_types_pkg::*;

package riscv_lsu_types_pkg;

  typedef struct packed {
    logic valid;  // entry allocated
    logic addr_valid;
    logic [4:0] addr;

    /// Load has completed
    logic executed;
    logic sleeping;  // waiting on older store data
    logic succeeded;  // result available
    logic from_forward;  // result came from store forwarding
    logic from_mem;  // result came from memory

    /// Older stores this load depends on
    logic [31:0] st_dep_mask;
  } ldq_entry_t;

  typedef struct packed {
    logic valid;  // entry allocated
    logic committed;  // ROB committed
    logic addr_valid;
    logic [4:0] addr;
    logic data_valid;
    word_t data;
  } stq_entry_t;

endpackage : riscv_lsu_types_pkg
