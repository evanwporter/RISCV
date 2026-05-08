`ifndef RISCV_UTIL_SVH
`define RISCV_UTIL_SVH

`define RV_ASSERT(COND, FMT_ARGS) \
  if (!(COND)) begin \
    riscv_util_pkg::rv_assert_fail(`__FILE__, `__LINE__, $sformatf FMT_ARGS); \
  end \

`endif // RISCV_UTIL_SVH
