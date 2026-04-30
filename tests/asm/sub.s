.section .text
.globl _start

_start:

  # -------------------------------------------------
  # TEST 1: sub basic
  # -------------------------------------------------
  addi x1, x0, 10
  addi x2, x0, 3
  sub  x3, x1, x2       # 10 - 3 = 7
  addi x31, x0, 7
  bne  x3, x31, fail1

  # -------------------------------------------------
  # TEST 2: sub negative result
  # -------------------------------------------------
  addi x1, x0, 3
  addi x2, x0, 10
  sub  x3, x1, x2       # 3 - 10 = -7
  addi x31, x0, -7
  bne  x3, x31, fail2

  # -------------------------------------------------
  # TEST 3: subtract zero
  # -------------------------------------------------
  addi x1, x0, 5
  sub  x3, x1, x0       # 5 - 0 = 5
  addi x31, x0, 5
  bne  x3, x31, fail3

  # -------------------------------------------------
  # TEST 4: zero result
  # -------------------------------------------------
  addi x1, x0, 8
  addi x2, x0, 8
  sub  x3, x1, x2       # 8 - 8 = 0
  addi x31, x0, 0
  bne  x3, x31, fail4

  # -------------------------------------------------
  # TEST 5: dependency chain
  # -------------------------------------------------
  addi x1, x0, 20
  addi x2, x0, 5
  sub  x3, x1, x2       # 15
  sub  x4, x3, x2       # 10
  addi x31, x0, 10
  bne  x4, x31, fail5

  # -------------------------------------------------
  # TEST 6: x0 must stay zero
  # -------------------------------------------------
  addi x1, x0, 9
  addi x2, x0, 4
  sub  x0, x1, x2       # should be ignored
  bne  x0, x0, fail6

  # -------------------------------------------------
  # PASS
  # -------------------------------------------------
pass:
  addi x10, x0, -1       # x10 = -1 means PASS
  beq  x0, x0, pass

# -------------------------------------------------
# FAIL HANDLERS (encode failure ID in x10)
# -------------------------------------------------

fail1: addi x10, x0, 1;  beq x0,x0, fail1
fail2: addi x10, x0, 2;  beq x0,x0, fail2
fail3: addi x10, x0, 3;  beq x0,x0, fail3
fail4: addi x10, x0, 4;  beq x0,x0, fail4
fail5: addi x10, x0, 5;  beq x0,x0, fail5
fail6: addi x10, x0, 6;  beq x0,x0, fail6
