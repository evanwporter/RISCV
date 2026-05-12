.section .bss
.balign 4

buffer:
    .space 1024

program:
    .space 30000

char_buff:
    .space 1

.balign 4
file_size:
    .word 0

fd:
    .word 0

    .section .data

dne_error_msg:
    .ascii "We couldn't find the file :(\n"

dne_error_msg_end:
    .equ dne_error_msg_len, dne_error_msg_end - dne_error_msg


    .section .text
    .global _start

    # --------------------------------------------------------------------
    # Syscall numbers.
    #
    # These are Linux RISC-V syscall numbers.
    # If your emulator uses your C enum, change these:
    #
    #   SYS_READ  = 0
    #   SYS_WRITE = 3
    #
    # RISC-V Linux does not use old x86 open=5.
    # Use openat=56 instead.
    # --------------------------------------------------------------------

    .equ SYS_READ,   63
    .equ SYS_WRITE,  64
    .equ SYS_OPENAT, 56
    .equ SYS_CLOSE,  57
    .equ SYS_EXIT,   93

    .equ AT_FDCWD,   -100
    .equ O_RDONLY,   0


# ------------------------------------------------------------------------
# print
#
# Arguments:
#   a0 = pointer
#   a1 = length
#
# Clobbers:
#   a0, a1, a2, a7, t0, t1
# ------------------------------------------------------------------------

print:
    addi sp, sp, -4
    sw ra, 0(sp)

    mv t0, a0              # save pointer
    mv t1, a1              # save length

    li a7, SYS_WRITE
    li a0, 1               # fd = stdout
    mv a1, t0              # buf
    mv a2, t1              # len
    ecall

    lw ra, 0(sp)
    addi sp, sp, 4
    ret


# ------------------------------------------------------------------------
# file_open
#
# Argument:
#   a0 = filename pointer
#
# Returns:
#   a0 = fd, or negative errno
#
# Uses:
#   openat(AT_FDCWD, filename, O_RDONLY, 0)
# ------------------------------------------------------------------------

file_open:
    mv t0, a0              # filename pointer

    li a7, SYS_OPENAT
    li a0, AT_FDCWD
    mv a1, t0
    li a2, O_RDONLY
    li a3, 0
    ecall

    ret


# ------------------------------------------------------------------------
# file_read
#
# Argument:
#   a0 = fd
#
# Returns:
#   a0 = number of bytes read, or negative errno
# ------------------------------------------------------------------------

file_read:
    mv t0, a0              # fd

    li a7, SYS_READ
    mv a0, t0
    la a1, buffer
    li a2, 1024
    ecall

    ret


# ------------------------------------------------------------------------
# file_close
#
# Argument:
#   a0 = fd
# ------------------------------------------------------------------------

file_close:
    li a7, SYS_CLOSE
    ecall
    ret


# ------------------------------------------------------------------------
# dne_error
# ------------------------------------------------------------------------

dne_error:
    la a0, dne_error_msg
    li a1, dne_error_msg_len
    jal ra, print

    j exit_0


# ------------------------------------------------------------------------
# interpreter
#
# Register usage:
#
#   s0 = current Brainfuck source pointer
#   s1 = end pointer of loaded source
#   s2 = Brainfuck tape pointer
#
# Runtime loop stack:
#
#   The program stack stores addresses of active '[' instructions.
# ------------------------------------------------------------------------

interpreter:
    lbu t0, 0(s0)

    li t1, '>'
    beq t0, t1, handle_right

    li t1, '<'
    beq t0, t1, handle_left

    li t1, '+'
    beq t0, t1, handle_inc

    li t1, '-'
    beq t0, t1, handle_dec

    li t1, '.'
    beq t0, t1, handle_out

    li t1, '['
    beq t0, t1, handle_loop_start

    li t1, ']'
    beq t0, t1, handle_loop_end

    j interp_done


handle_right:
    addi s2, s2, 1
    j interp_done


handle_left:
    addi s2, s2, -1
    j interp_done


handle_inc:
    lbu t0, 0(s2)
    addi t0, t0, 1
    sb t0, 0(s2)
    j interp_done


handle_dec:
    lbu t0, 0(s2)
    addi t0, t0, -1
    sb t0, 0(s2)
    j interp_done


handle_out:
    lbu t0, 0(s2)

    la t1, char_buff
    sb t0, 0(t1)

    mv a0, t1
    li a1, 1
    jal ra, print

    j interp_done


handle_loop_start:
    lbu t0, 0(s2)
    beqz t0, skip_forward

    # Push address of '[' onto runtime loop stack.
    addi sp, sp, -4
    sw s0, 0(sp)

    j interp_done


handle_loop_end:
    lbu t0, 0(s2)
    bnez t0, jump_back

    # Current cell is zero, so pop matching '['.
    addi sp, sp, 4

    j interp_done


jump_back:
    # Go back to matching '['.
    lw s0, 0(sp)
    j interp_done


# ------------------------------------------------------------------------
# skip_forward
#
# We are at '[' and current cell is zero.
# Move s0 forward to the matching ']'.
#
# t2 = nesting depth
# ------------------------------------------------------------------------

skip_forward:
    li t2, 0

skip_loop:
    addi s0, s0, 1

    # If EOF before matching ']', exit.
    bge s0, s1, exit_0

    lbu t0, 0(s0)

    li t1, '['
    beq t0, t1, skip_inc

    li t1, ']'
    beq t0, t1, skip_dec

    j skip_loop


skip_inc:
    addi t2, t2, 1
    j skip_loop


skip_dec:
    beqz t2, interp_done
    addi t2, t2, -1
    j skip_loop


interp_done:
    addi s0, s0, 1
    blt s0, s1, interpreter

    j exit_0


# ------------------------------------------------------------------------
# _start
#
# On RV32 Linux-style startup stack:
#
#   0(sp) = argc
#   4(sp) = argv[0]
#   8(sp) = argv[1]
# ------------------------------------------------------------------------

_start:
    lw t0, 0(sp)           # argc

    li t1, 2
    blt t0, t1, exit_0     # need at least argv[1]

    lw a0, 8(sp)           # argv[1] filename
    jal ra, file_open

    bltz a0, dne_error

    la t0, fd
    sw a0, 0(t0)

    jal ra, file_read

    bltz a0, exit_0

    la t0, file_size
    sw a0, 0(t0)

    la t0, fd
    lw a0, 0(t0)
    jal ra, file_close

    # s1 = buffer + file_size
    la s1, buffer
    la t0, file_size
    lw t1, 0(t0)
    add s1, s1, t1

    # s0 = current BF instruction pointer
    la s0, buffer

    # s2 = BF tape pointer
    la s2, program

    blt s0, s1, interpreter

    j exit_0


exit_0:
    li a7, SYS_EXIT
    li a0, 0
    ecall
