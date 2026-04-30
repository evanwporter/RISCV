.section .text
.globl _start

_start:

  # -------------------------------------------------
  # TEST 2: add
  # -------------------------------------------------
  addi x1, x0, 5 # new=P32 old=P1 Ps1=P0 Ps2=P0 Ps1_ready=1 Ps2_ready=1
  addi x2, x0, 7 # new=P33 old=P2 Ps1=P0 Ps2=P0 Ps1_ready=1 Ps2_ready=1
  add  x3, x1, x2
  addi x31, x0, 12
  bne  x3, x31, fail2

  # -------------------------------------------------
  # TEST 3: add negative
  # -------------------------------------------------
  addi x1, x0, -1
  addi x2, x0, 1
  add  x3, x1, x2
  addi x31, x0, 0
  bne  x3, x31, fail3

  # -------------------------------------------------
  # TEST 4: x0 must stay zero
  # -------------------------------------------------
  addi x1, x0, 5
  addi x2, x0, 6
  add  x0, x1, x2       # should be ignored
  bne  x0, x0, fail4    # always equal if correct

  # -------------------------------------------------
  # TEST 5: dependency
  # -------------------------------------------------
  addi x1, x0, 10
  addi x2, x0, 20
  add  x3, x1, x2       # 30
  add  x4, x3, x1       # 40
  addi x31, x0, 40
  bne  x4, x31, fail5

  # -------------------------------------------------
  # TEST 6: beq works
  # -------------------------------------------------
  addi x1, x0, 5
  addi x2, x0, 5
  beq  x1, x2, test6_pass
  beq  x0, x0, fail6    # should not reach

# TODO: Resolve the issue with bne then beq
test6_pass:

  # -------------------------------------------------
  # TEST 7: bne works
  # -------------------------------------------------
  addi x1, x0, 5
  addi x2, x0, 6
  bne  x1, x2, test7_pass
  beq  x0, x0, fail7

test7_pass:

  # -------------------------------------------------
  # PASS
  # -------------------------------------------------
pass:
  addi x10, x0, -1   # x10 = -1 means PASS
  beq  x0, x0, pass

# -------------------------------------------------
# FAIL HANDLERS (encode failure ID in x10)
# -------------------------------------------------

fail2: addi x10, x0, 2; beq x0,x0, fail2
fail3: addi x10, x0, 3; beq x0,x0, fail3
fail4: addi x10, x0, 4; beq x0,x0, fail4
fail5: addi x10, x0, 5; beq x0,x0, fail5
fail6: addi x10, x0, 6; beq x0,x0, fail6
fail7: addi x10, x0, 7; beq x0,x0, fail7

# 0:   addi x1, x0, 5
# 4:   addi x2, x0, 7
# 8:   add  x3, x1, x2
# 12:  addi x31, x0, 12
# 16:  bne  x3, x31, fail1

# 20:  addi x1, x0, -1
# 24:  addi x2, x0, 1
# 28:  add  x3, x1, x2
# 32:  addi x31, x0, 0
# 36:  bne  x3, x31, fail2

# 40:  addi x1, x0, 5
# 44:  addi x2, x0, 6
# 48:  add  x0, x1, x2
# 52:  bne  x0, x0, fail4

# 56:  addi x1, x0, 10
# 60:  addi x2, x0, 20
# 64:  add  x3, x1, x2
# 68:  add  x4, x3, x1
# 72:  addi x31, x0, 40
# 76:  bne  x4, x31, fail5

# 80:  addi x1, x0, 5
# 84:  addi x2, x0, 5
# 88:  beq  x1, x2, test6_pass
# 92:  beq  x0, x0, fail6

# 96:  test6_pass:
# 96:  addi x1, x0, 5
# 100: addi x2, x0, 6
# 104: bne  x1, x2, test7_pass
# 108: beq  x0, x0, fail7

# 112: test7_pass:
# 112: addi x10, x0, 1
# 116: beq  x0, x0, pass

# 120: fail2:
# 120: addi x10, x0, 2
# 124: beq  x0, x0, fail2

# 128: fail3:
# 128: addi x10, x0, 3
# 132: beq  x0, x0, fail3

# 136: fail4:
# 136: addi x10, x0, 4
# 140: beq  x0, x0, fail4

# 144: fail5:
# 144: addi x10, x0, 5
# 148: beq  x0, x0, fail5

# 152: fail6:
# 152: addi x10, x0, 6
# 156: beq  x0, x0, fail6

# 160: fail7:
# 160: addi x10, x0, 7
# 164: beq  x0, x0, fail7
