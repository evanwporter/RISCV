#ifndef _CUSTOM_RISCV_TEST_H
#define _CUSTOM_RISCV_TEST_H

#define TESTNUM x28

#define RVTEST_RV32U
#define RVTEST_RV64U RVTEST_RV32U

// clang-format off
#define RVTEST_CODE_BEGIN \
    .section .text;        \
    .align 2;             \
    .globl _start;        \
    _start:               \
    li x1, 0;             \
    li x2, 0;             \
    li x3, 0;             \
    li x4, 0;             \
    li x5, 0;             \
    li x6, 0;             \
    li x7, 0;             \
    li x8, 0;             \
    li x9, 0;             \
    li x10, 0;            \
    li x11, 0;            \
    li x12, 0;            \
    li x13, 0;            \
    li x14, 0;            \
    li x15, 0;            \
    li x16, 0;            \
    li x17, 0;            \
    li x18, 0;            \
    li x19, 0;            \
    li x20, 0;            \
    li x21, 0;            \
    li x22, 0;            \
    li x23, 0;            \
    li x24, 0;            \
    li x25, 0;            \
    li x26, 0;            \
    li x27, 0;            \
    li x28, 0;            \
    li x29, 0;            \
    li x30, 0;            \
    li x31, 0;

#define RVTEST_CODE_END \
    1 : beq x0, x0, 1b

#define RVTEST_PASS \
    li x10, 1;      \
    la x5, tohost;  \
    sw x10, 0(x5);  \
    1 : beq x0, x0, 1b

#define RVTEST_FAIL       \
    addi x10, TESTNUM, 0; \
    slli x10, x10, 1;     \
    ori x10, x10, 1;      \
    la x5, tohost;        \
    sw x10, 0(x5);        \
    1 : beq x0, x0, 1b

#define RVTEST_DATA_BEGIN             \
    .section .tohost, "aw", @progbits; \
    .align 4;                         \
    .globl tohost;                    \
    tohost:                           \
    .word 0;                          \
    .globl fromhost;                  \
    fromhost:                         \
    .word 0;                          \
    .section .data;                    \
    .align 4;                         \
    .globl begin_signature;           \
    begin_signature:

#define RVTEST_DATA_END   \
    .align 4;             \
    .globl end_signature; \
    end_signature:

// clang-format on

#define RVTEST_DATA

#endif