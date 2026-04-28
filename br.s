.section .text
.globl _start

_start:
  addi x1, x0, 5        # PC = 0
  addi x2, x0, 7        # PC = 4
  add  x3, x1, x2       # PC = 8
  addi x31, x0, 12      # PC = 12
  beq  x3, x31, pass    # PC = 16

fail:
  addi x10, x0, 2       # PC = 20
  beq  x0, x0, fail     # PC = 24

pass:
  addi x10, x0, -1      # PC = 28
  beq  x0, x0, pass     # PC = 32

padding:
  addi x0, x0, 0        # PC = 36
  addi x0, x0, 0        # PC = 40
  addi x0, x0, 0        # PC = 44
  addi x0, x0, 0        # PC = 48
  addi x0, x0, 0        # PC = 52
  addi x0, x0, 0        # PC = 56
  addi x0, x0, 0        # PC = 60
  addi x0, x0, 0        # PC = 64
  addi x0, x0, 0        # PC = 68
  addi x0, x0, 0        # PC = 72

  addi x0, x0, 0        # PC = 76
  addi x0, x0, 0        # PC = 80
  addi x0, x0, 0        # PC = 84
  addi x0, x0, 0        # PC = 88
  addi x0, x0, 0        # PC = 92
  addi x0, x0, 0        # PC = 96
  addi x0, x0, 0        # PC = 100
  addi x0, x0, 0        # PC = 104
  addi x0, x0, 0        # PC = 108
  addi x0, x0, 0        # PC = 112

  addi x0, x0, 0        # PC = 116
  addi x0, x0, 0        # PC = 120
  addi x0, x0, 0        # PC = 124
  addi x0, x0, 0        # PC = 128
  addi x0, x0, 0        # PC = 132
  addi x0, x0, 0        # PC = 136
  addi x0, x0, 0        # PC = 140
  addi x0, x0, 0        # PC = 144
  addi x0, x0, 0        # PC = 148
  addi x0, x0, 0        # PC = 152
  