.section .text
.globl _start

_start:

  # TEST 1: add
  addi x1, x0, 5
  addi x2, x0, 7
  add  x3, x1, x2
  addi x31, x0, 12
  bne  x3, x31, fail1

  # TEST 2: sub
  addi x1, x0, 9
  addi x2, x0, 4
  sub  x3, x1, x2
  addi x31, x0, 5
  bne  x3, x31, fail2

  # TEST 3: sll
  addi x1, x0, 3
  addi x2, x0, 2
  sll  x3, x1, x2
  addi x31, x0, 12
  bne  x3, x31, fail3

  # TEST 4: slt signed true
  addi x1, x0, -1
  addi x2, x0, 1
  slt  x3, x1, x2
  addi x31, x0, 1
  bne  x3, x31, fail4

  # TEST 5: sltu unsigned false
  addi x1, x0, -1
  addi x2, x0, 1
  sltu x3, x1, x2
  addi x31, x0, 0
  bne  x3, x31, fail5

  # TEST 6: xor
  addi x1, x0, 10       # 1010
  addi x2, x0, 12       # 1100
  xor  x3, x1, x2       # 0110
  addi x31, x0, 6
  bne  x3, x31, fail6

  # TEST 7: srl
  addi x1, x0, 8
  addi x2, x0, 1
  srl  x3, x1, x2
  addi x31, x0, 4
  bne  x3, x31, fail7

  # TEST 8: sra
  addi x1, x0, -8
  addi x2, x0, 1
  sra  x3, x1, x2
  addi x31, x0, -4
  bne  x3, x31, fail8

  # TEST 9: or
  addi x1, x0, 10       # 1010
  addi x2, x0, 12       # 1100
  or   x3, x1, x2       # 1110
  addi x31, x0, 14
  bne  x3, x31, fail9

  # TEST 10: and
  addi x1, x0, 10       # 1010
  addi x2, x0, 12       # 1100
  and  x3, x1, x2       # 1000
  addi x31, x0, 8
  bne  x3, x31, fail10

  # TEST 11: addi
  addi x3, x0, 11
  addi x31, x0, 11
  bne  x3, x31, fail11

  # TEST 12: slti signed true
  addi x1, x0, -1
  slti x3, x1, 1
  addi x31, x0, 1
  bne  x3, x31, fail12

  # TEST 13: sltiu unsigned false
  addi  x1, x0, -1
  sltiu x3, x1, 1
  addi  x31, x0, 0
  bne   x3, x31, fail13

  # TEST 14: xori
  addi x1, x0, 10
  xori x3, x1, 12
  addi x31, x0, 6
  bne  x3, x31, fail14

  # TEST 15: ori
  addi x1, x0, 10
  ori  x3, x1, 12
  addi x31, x0, 14
  bne  x3, x31, fail15

  # TEST 16: andi
  addi x1, x0, 10
  andi x3, x1, 12
  addi x31, x0, 8
  bne  x3, x31, fail16

  # TEST 17: slli
  addi x1, x0, 3
  slli x3, x1, 2
  addi x31, x0, 12
  bne  x3, x31, fail17

  # TEST 18: srli
  addi x1, x0, 8
  srli x3, x1, 1
  addi x31, x0, 4
  bne  x3, x31, fail18

  # TEST 19: srai
  addi x1, x0, -8
  srai x3, x1, 1
  addi x31, x0, -4
  bne  x3, x31, fail19

  # TEST 20: x0 stays zero
  addi x1, x0, 5
  addi x2, x0, 6
  add  x0, x1, x2
  addi x31, x0, 0
  bne  x0, x31, fail20

pass:
  addi x10, x0, -1
  beq  x0, x0, pass

fail1:  addi x10, x0, 1;  beq x0, x0, fail1
fail2:  addi x10, x0, 2;  beq x0, x0, fail2
fail3:  addi x10, x0, 3;  beq x0, x0, fail3
fail4:  addi x10, x0, 4;  beq x0, x0, fail4
fail5:  addi x10, x0, 5;  beq x0, x0, fail5
fail6:  addi x10, x0, 6;  beq x0, x0, fail6
fail7:  addi x10, x0, 7;  beq x0, x0, fail7
fail8:  addi x10, x0, 8;  beq x0, x0, fail8
fail9:  addi x10, x0, 9;  beq x0, x0, fail9
fail10: addi x10, x0, 10; beq x0, x0, fail10
fail11: addi x10, x0, 11; beq x0, x0, fail11
fail12: addi x10, x0, 12; beq x0, x0, fail12
fail13: addi x10, x0, 13; beq x0, x0, fail13
fail14: addi x10, x0, 14; beq x0, x0, fail14
fail15: addi x10, x0, 15; beq x0, x0, fail15
fail16: addi x10, x0, 16; beq x0, x0, fail16
fail17: addi x10, x0, 17; beq x0, x0, fail17
fail18: addi x10, x0, 18; beq x0, x0, fail18
fail19: addi x10, x0, 19; beq x0, x0, fail19
fail20: addi x10, x0, 20; beq x0, x0, fail20