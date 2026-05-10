import riscv_types_pkg::*;
import riscv_constants_pkg::*;
import riscv_regs_types_pkg::*;

interface Syscall_if;

  logic  ecall_valid;
  addr_t ecall_pc;

  word_t a0, a1, a2, a7;

  word_t result;
  logic result_valid;

  logic halt;

  physical_reg_t RAT_10;

  typedef struct packed {
    logic  valid;
    word_t result;
  } syscall_res_t;

  syscall_res_t [COMMIT_WIDTH-1:0] syscall_req;

  modport Syscall_Side(
      input ecall_valid,
      input ecall_pc,
      input a0,
      input a1,
      input a2,
      input a7,
      input halt,
      output syscall_req
  );

  modport ReorderBuffer_Side(input ecall_valid, input ecall_pc);

  modport RegisterFile_Side(input syscall_req, input RAT_10);

endinterface : Syscall_if
