import riscv_constants_pkg::*;

package riscv_util_pkg;
  function automatic logic is_younger(input logic [ROB_IDX_WIDTH-1:0] entry_idx,
                                      input logic [ROB_IDX_WIDTH-1:0] ref_idx,
                                      input logic [ROB_IDX_WIDTH-1:0] head);
    logic [ROB_IDX_WIDTH-1:0] entry_age;
    logic [ROB_IDX_WIDTH-1:0] ref_age;

    entry_age = entry_idx - head;
    ref_age = ref_idx - head;

    is_younger = entry_age > ref_age;
  endfunction

  function automatic logic is_older(input logic [ROB_IDX_WIDTH-1:0] entry_idx,
                                    input logic [ROB_IDX_WIDTH-1:0] ref_idx,
                                    input logic [ROB_IDX_WIDTH-1:0] head);
    logic [ROB_IDX_WIDTH-1:0] entry_age;
    logic [ROB_IDX_WIDTH-1:0] ref_age;

    entry_age = entry_idx - head;
    ref_age   = ref_idx - head;

    is_older  = entry_age < ref_age;
  endfunction
endpackage : riscv_util_pkg
