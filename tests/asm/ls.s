.section .text
.globl _start

_start:

test1:
  # PC = 0
  addi x1, x0, 42 # load data value to store

  # PC = 4
  addi x2, x0, 32 # set address to store to and load from

  # PC = 8
  sw x1, 0(x2) # store 42 at address 0

  # PC = 12
  lw x3, 0(x2) # load 42 into x3

  # PC = 16
  addi x31, x0, 42 # load expected value into x31

  # PC = 20
  bne  x3, x31, fail1

test2:
  # PC = 24
  addi x1, x0, 99

  # PC = 28
  sw   x1, 4(x2)

  # PC = 32
  lw   x4, 4(x2)

  # PC = 36
  addi x31, x0, 99

  # PC = 40
  bne  x4, x31, fail2


pass:
  # PC = 44
  addi x10, x0, -1

  # PC = 48
  beq  x0, x0, pass

fail1:
  # PC = 52
  addi x10, x0, 1

  # PC = 56
  beq  x0, x0, fail1

fail2:
  # PC = 60
  addi x10, x0, 2

  # PC = 64
  beq  x0, x0, fail2