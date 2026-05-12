.section .text

.global __syscall3
.type __syscall3, @function

# long __syscall3(long num, long arg0, long arg1, long arg2)
__syscall3:
    mv a7, a0
    mv a0, a1
    mv a1, a2
    mv a2, a3
    ecall
    ret

.size __syscall3, . - __syscall3

.global __syscall4
.type __syscall4, @function

# long __syscall4(long num, long arg0, long arg1, long arg2, long arg3)
__syscall4:
    mv a7, a0
    mv a0, a1
    mv a1, a2
    mv a2, a3
    mv a3, a4
    ecall
    ret

.size __syscall4, . - __syscall4