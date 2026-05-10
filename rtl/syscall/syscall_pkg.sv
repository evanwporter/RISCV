package syscall_pkg;

  import "DPI-C" function int rv_syscall(
    input  int syscall_num,
    input  int arg0,
    input  int arg1,
    input  int arg2,
    input  int pc,
    output int halt
  );

endpackage
