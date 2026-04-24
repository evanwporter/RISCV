.section .text
.globl _start

_start:

  # -------------------------------------------------
  # TEST 1: beq taken
  # -------------------------------------------------
  addi x1, x0, 5
  addi x2, x0, 5
  beq  x1, x2, test1_pass
  beq  x0, x0, fail1   # should NOT hit

test1_pass:

  # -------------------------------------------------
  # TEST 2: beq not taken
  # -------------------------------------------------
  addi x1, x0, 5
  addi x2, x0, 6
  beq  x1, x2, fail2   # should NOT branch

  # fallthrough = pass
test2_pass:

  # -------------------------------------------------
  # TEST 3: bne taken
  # -------------------------------------------------
  addi x1, x0, 1
  addi x2, x0, 2
  bne  x1, x2, test3_pass
  beq  x0, x0, fail3

test3_pass:

  # -------------------------------------------------
  # TEST 4: bne not taken
  # -------------------------------------------------
  addi x1, x0, 9
  addi x2, x0, 9
  bne  x1, x2, fail4   # should NOT branch

test4_pass:

  # -------------------------------------------------
  # TEST 5: zero register branch
  # -------------------------------------------------
  addi x1, x0, 0
  beq  x1, x0, test5_pass
  beq  x0, x0, fail5

test5_pass:

  # -------------------------------------------------
  # TEST 6: backward branch (loop once)
  # -------------------------------------------------
  addi x1, x0, 1

loop:
  addi x1, x1, -1
  bne  x1, x0, loop    # should loop exactly once

  beq  x0, x0, test6_pass

test6_pass:

  # -------------------------------------------------
  # PASS
  # -------------------------------------------------
pass:
  addi x10, x0, 1
  beq  x0, x0, pass

# -------------------------------------------------
# FAIL HANDLERS
# -------------------------------------------------
fail1: addi x10, x0, 1; beq x0,x0, fail1
fail2: addi x10, x0, 2; beq x0,x0, fail2
fail3: addi x10, x0, 3; beq x0,x0, fail3
fail4: addi x10, x0, 4; beq x0,x0, fail4
fail5: addi x10, x0, 5; beq x0,x0, fail5