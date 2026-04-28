package riscv_constants_pkg;

  // localparam int NUM_LOGICAL_REGS = 32;
  localparam int NUM_PHYSICAL_REGS = 64;

  /// TODO: the amount that can be popped from the iq should not depend on commit width
  /// ALso this breaks the ls when its 4 due to popping mispredicted branches off of ROB
  localparam int COMMIT_WIDTH = 2;

  localparam int STQ_WIDTH = 4;
  localparam int STQ_IDX_WIDTH = $clog2(STQ_WIDTH);

  localparam int LDQ_WIDTH = 4;
  localparam int LDQ_IDX_WIDTH = $clog2(LDQ_WIDTH);

  localparam int ROB_WIDTH = 32;
  localparam int ROB_IDX_WIDTH = $clog2(ROB_WIDTH);

  localparam int IQ_WIDTH = 32;
  localparam int IQ_IDX_WIDTH = $clog2(IQ_WIDTH);
endpackage : riscv_constants_pkg
