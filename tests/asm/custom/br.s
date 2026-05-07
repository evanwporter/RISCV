.section .text
.globl _start

_start:
  # TEST 1: add, then branch NOT taken
  addi x1, x0, 5
  addi x2, x0, 7
  add  x3, x1, x2        # x3 = 12

  addi x31, x0, 13
  beq  x3, x31, fail1    # should NOT branch

  # TEST 2: branch taken forward
  addi x31, x0, 12
  beq  x3, x31, good1    # should branch

  beq  x0, x0, fail2     # should be skipped

good1:
  # TEST 3: small backward loop
  # Count x4 from 0 to 3
  addi x4, x0, 0
  addi x5, x0, 3

loop_count:
  addi x4, x4, 1
  bne  x4, x5, loop_count

  addi x31, x0, 3
  bne  x4, x31, fail3

  # TEST 4: branch over bad code
  addi x6, x0, 9
  addi x7, x0, 9
  beq  x6, x7, skip_bad

  # Should never execute
  addi x10, x0, 99
  beq  x0, x0, fail4

skip_bad:
  addi x8, x0, 22
  addi x31, x0, 22
  bne  x8, x31, fail5

  # TEST 5: sum loop
  # Compute 1 + 2 + 3 = 6
  addi x9,  x0, 0        # sum = 0
  addi x11, x0, 1        # i = 1
  addi x12, x0, 4        # stop when i == 4

loop_sum:
  add  x9, x9, x11       # sum += i
  addi x11, x11, 1       # i++
  bne  x11, x12, loop_sum

  addi x31, x0, 6
  bne  x9, x31, fail6 # PC 116

pass:
  addi x10, x0, -1
  beq  x0, x0, pass

fail1:
  addi x10, x0, 1
  beq  x0, x0, fail1

fail2:
  addi x10, x0, 2
  beq  x0, x0, fail2

fail3:
  addi x10, x0, 3
  beq  x0, x0, fail3

fail4:
  addi x10, x0, 4
  beq  x0, x0, fail4

fail5:
  addi x10, x0, 5
  beq  x0, x0, fail5

fail6:
  addi x10, x0, 6
  beq  x0, x0, fail6