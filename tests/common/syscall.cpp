// _write
// _read
// _sbrk
// _close
// _fstat
// _isatty
// _lseek
// _exit

#include <cerrno>
#include <cstddef>
#include <sys/stat.h>
#include <sys/types.h>

enum class SyscallNum : long {
    Openat = 56,
    Close = 57,
    Read = 63,
    Write = 64,
    Fstat = 80,
    Lseek = 62,
    Exit = 93,
    Brk = 214,
};

extern "C" long __syscall3(long num, long arg0, long arg1, long arg2);
extern "C" long __syscall4(long num, long arg0, long arg1, long arg2, long arg3);

static int ret_to_errno(long ret) {
    if (ret < 0) {
        errno = static_cast<int>(-ret);
        return -1;
    }

    return static_cast<int>(ret);
}

extern "C" int _write(int fd, const void* buf, size_t nbyte) {
    long ret = __syscall3(
        static_cast<long>(SyscallNum::Write),
        static_cast<long>(fd),
        reinterpret_cast<long>(buf),
        static_cast<long>(nbyte));

    return ret_to_errno(ret);
}

extern "C" int _read(int fd, void* buf, size_t count) {
    long ret = __syscall3(
        static_cast<long>(SyscallNum::Read),
        static_cast<long>(fd),
        reinterpret_cast<long>(buf),
        static_cast<long>(count));

    return ret_to_errno(ret);
}

extern "C" int _open(const char* path, int flags, int mode) {
    constexpr long AT_FDCWD = -100;

    long ret = __syscall4(
        static_cast<long>(SyscallNum::Openat),
        AT_FDCWD,
        reinterpret_cast<long>(path),
        static_cast<long>(flags),
        static_cast<long>(mode));

    return ret_to_errno(ret);
}