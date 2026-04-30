.section .text
.globl _start

_start:

  # PC = 0
  addi x1, x0, 42 # load data value to store

  # PC = 4
  addi x2, x0, 32 # set address to store to and load from

  # PC = 8
  sw x1, 0(x2) # store 42 at address 0

  # PC = 12
  lw x3, 0(x2) # load 42 into x3

  # PC = 16
  addi x31, x0, 42

  # PC = 20
  bne  x3, x31, fail1

pass:
  # PC = 24
  addi x10, x0, -1

  # PC = 28
  beq  x0, x0, pass

fail1:
  # PC = 32
  addi x10, x0, 1

  # PC = 36
  beq  x0, x0, fail1