import riscv_constants_pkg::*;

package riscv_util_pkg;
  function automatic logic is_younger(input logic [ROB_IDX_WIDTH-1:0] a,
                                      input logic [ROB_IDX_WIDTH-1:0] b);
    if (a == b) return 0;
    return (a - b) < ROB_WIDTH / 2;
  endfunction

  function automatic logic is_older(input logic [ROB_IDX_WIDTH-1:0] a,
                                    input logic [ROB_IDX_WIDTH-1:0] b);
    // is a older than b
    return a < b;
  endfunction
endpackage : riscv_util_pkg
