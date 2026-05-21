#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstddef>

#if defined(_WIN32)
    #include <fcntl.h>
    #include <io.h>
    #include <sys/stat.h>

    using host_stat_t = struct _stat;

    static int host_read(int fd, void* buf, unsigned int count) {
        return _read(fd, buf, count);
    }

    static int host_write(int fd, const void* buf, unsigned int count) {
        return _write(fd, buf, count);
    }

    static int host_close(int fd) {
        return _close(fd);
    }

    static long host_lseek(int fd, long offset, int whence) {
        return _lseek(fd, offset, whence);
    }

    static int host_isatty(int fd) {
        return _isatty(fd);
    }

    static int host_fstat(int fd, host_stat_t* st) {
        return _fstat(fd, st);
    }

#else
    #include <fcntl.h>
    #include <unistd.h>
    #include <sys/stat.h>
    #include <sys/types.h>

    using host_stat_t = struct stat;

    static ssize_t host_read(int fd, void* buf, size_t count) {
        return ::read(fd, buf, count);
    }

    static ssize_t host_write(int fd, const void* buf, size_t count) {
        return ::write(fd, buf, count);
    }

    static int host_close(int fd) {
        return ::close(fd);
    }

    static off_t host_lseek(int fd, off_t offset, int whence) {
        return ::lseek(fd, offset, whence);
    }

    static int host_isatty(int fd) {
        return ::isatty(fd);
    }

    static int host_fstat(int fd, host_stat_t* st) {
        return ::fstat(fd, st);
    }

#endif

extern "C" {

// You must provide these from your simulator memory implementation.
uint8_t* rv_translate_ptr(uint32_t guest_addr) {
    return nullptr;
}

bool rv_copy_from_guest(void* dst, uint32_t guest_addr, size_t size) {
    return false;
}

bool rv_copy_to_guest(uint32_t guest_addr, const void* src, size_t size) {
    return false;
}

}

enum SyscallNum : int {
    SYS_read  = 63,
    SYS_write = 64,
    SYS_close = 57,
    SYS_fstat = 80,
    SYS_lseek = 62,
    SYS_exit  = 93,
    SYS_isatty = 89,
    SYS_brk   = 214,
};

static int neg_errno() {
    return errno ? -errno : -EIO;
}

extern "C" int rv_syscall(
    int syscall_num,
    int arg0,
    int arg1,
    int arg2,
    int pc,
    int* halt) {
    if (!halt) {
        return -EFAULT;
    }

    *halt = 0;

    const uint32_t uarg0 = static_cast<uint32_t>(arg0);
    const uint32_t uarg1 = static_cast<uint32_t>(arg1);
    const uint32_t uarg2 = static_cast<uint32_t>(arg2);

    switch (syscall_num) {
    case SYS_read: {
        // read(fd, guest_buf, count)
        const int fd = arg0;
        const uint32_t guest_buf = uarg1;
        const size_t count = static_cast<size_t>(uarg2);

        uint8_t* host_buf = rv_translate_ptr(guest_buf);
        if (!host_buf) {
            return -EFAULT;
        }

        errno = 0;
        auto ret = host_read(fd, host_buf, count);
        if (ret < 0) {
            return neg_errno();
        }

        return static_cast<int>(ret);
    }

    case SYS_write: {
        // write(fd, guest_buf, count)
        const int fd = arg0;
        const uint32_t guest_buf = uarg1;
        const size_t count = static_cast<size_t>(uarg2);

        const uint8_t* host_buf = rv_translate_ptr(guest_buf);
        if (!host_buf) {
            return -EFAULT;
        }

        errno = 0;
        auto ret = host_write(fd, host_buf, count);
        if (ret < 0) {
            return neg_errno();
        }

        return static_cast<int>(ret);
    }

    case SYS_close: {
        // close(fd)
        errno = 0;
        int ret = host_close(arg0);
        if (ret < 0) {
            return neg_errno();
        }

        return ret;
    }

    case SYS_lseek: {
        // lseek(fd, offset, whence)
        errno = 0;
        auto ret = host_lseek(arg0, static_cast<long>(arg1), arg2);
        if (ret < 0) {
            return neg_errno();
        }

        return static_cast<int>(ret);
    }

    case SYS_isatty: {
        // isatty(fd)
        errno = 0;
        int ret = host_isatty(arg0);

        if (ret == 0) {
            if (errno == 0) {
                errno = ENOTTY;
            }
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
        // This direct copy is only safe if your guest libc expects
        // a compatible layout.
        host_stat_t st;
        std::memset(&st, 0, sizeof(st));

        errno = 0;
        int ret = host_fstat(arg0, &st);
        if (ret < 0) {
            return neg_errno();
        }

        if (!rv_copy_to_guest(uarg1, &st, sizeof(st))) {
            return -EFAULT;
        }

        return 0;
    }

    case SYS_exit: {
        // exit(status)
        std::fprintf(
            stderr,
            "rv_syscall: exit(%d) at pc=0x%08x\n",
            arg0,
            static_cast<uint32_t>(pc));

        *halt = 1;
        return 0;
    }

    case SYS_brk: {
        // brk(addr)
        //
        // Proper brk needs emulator heap tracking.
        // Returning 0 usually means failure for Linux brk semantics.
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