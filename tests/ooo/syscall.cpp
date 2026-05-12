#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <io.h>
#include <sys/stat.h>

extern "C" {

// You must provide these from your simulator memory implementation.
uint8_t* rv_translate_ptr(uint32_t guest_addr) {
    return nullptr;
};
bool rv_copy_from_guest(void* dst, uint32_t guest_addr, size_t size) {
    return false;
};
bool rv_copy_to_guest(uint32_t guest_addr, const void* src, size_t size) {
    return false;
};
}

enum SyscallNum : int {
    SYS_read = 63,
    SYS_write = 64,
    SYS_close = 57,
    SYS_fstat = 80,
    SYS_lseek = 62,
    SYS_exit = 93,
    SYS_isatty = 89,
    SYS_brk = 214,
};

static int ret_errno(long ret) {
    if (ret < 0) {
        return -errno;
    }

    return static_cast<int>(ret);
}

extern "C" int rv_syscall(
    int syscall_num,
    int arg0,
    int arg1,
    int arg2,
    int pc,
    int* halt) {
    *halt = 0;

    const uint32_t uarg0 = static_cast<uint32_t>(arg0);
    const uint32_t uarg1 = static_cast<uint32_t>(arg1);
    const uint32_t uarg2 = static_cast<uint32_t>(arg2);

    switch (syscall_num) {
    case SYS_read: {
        // read(fd, guest_buf, count)
        const int fd = arg0;
        const uint32_t guest_buf = uarg1;
        const size_t count = uarg2;

        uint8_t* host_buf = rv_translate_ptr(guest_buf);
        if (!host_buf) {
            return -EFAULT;
        }

        std::size_t ret = _read(fd, host_buf, count);
        if (ret < 0) {
            return -errno;
        }

        return static_cast<int>(ret);
    }

    case SYS_write: {
        // write(fd, guest_buf, count)
        const int fd = arg0;
        const uint32_t guest_buf = uarg1;
        const size_t count = uarg2;

        const uint8_t* host_buf = rv_translate_ptr(guest_buf);
        if (!host_buf) {
            return -EFAULT;
        }

        std::size_t ret = _write(fd, host_buf, count);
        if (ret < 0) {
            return -errno;
        }

        return static_cast<int>(ret);
    }

    case SYS_close: {
        // close(fd)
        int ret = ::close(arg0);
        if (ret < 0) {
            return -errno;
        }

        return ret;
    }

    case SYS_lseek: {
        // lseek(fd, offset, whence)
        off_t ret = _lseek(arg0, static_cast<off_t>(arg1), arg2);
        if (ret < 0) {
            return -errno;
        }

        return static_cast<int>(ret);
    }

    case SYS_isatty: {
        // isatty(fd)
        int ret = _isatty(arg0);
        if (ret == 0) {
            return -errno;
        }

        return ret;
    }

    case SYS_fstat: {
        // fstat(fd, guest_stat_ptr)
        //
        // Warning:
        // Host struct stat layout is not necessarily the same as
        // RISC-V newlib's struct stat layout.
        //
        // For many bare-metal/newlib-style ports, returning zero with
        // a mostly-zero struct is enough.
        struct stat st;
        std::memset(&st, 0, sizeof(st));

        int ret = ::fstat(arg0, &st);
        if (ret < 0) {
            return -errno;
        }

        // Simplest version: copy host struct stat directly.
        // This only works if your guest libc expects a compatible layout.
        if (!rv_copy_to_guest(uarg1, &st, sizeof(st))) {
            return -EFAULT;
        }

        return 0;
    }

    case SYS_exit: {
        // exit(status)
        std::fprintf(stderr, "rv_syscall: exit(%d) at pc=0x%08x\n", arg0, pc);
        *halt = 1;
        return 0;
    }

    case SYS_brk: {
        // brk(addr)
        //
        // Proper brk needs emulator heap tracking.
        // Returning 0 usually means failure for Linux brk semantics.
        // Better: implement your own guest heap pointer.
        return 0;
    }

    default:
        std::fprintf(
            stderr,
            "rv_syscall: unhandled syscall %d at pc=0x%08x "
            "args=(0x%08x, 0x%08x, 0x%08x)\n",
            syscall_num,
            static_cast<uint32_t>(pc),
            uarg0,
            uarg1,
            uarg2);

        return -ENOSYS;
    }
}