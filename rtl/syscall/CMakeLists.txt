rv_add_rtl(
    PACKAGES
        ${CMAKE_CURRENT_SOURCE_DIR}/syscall_pkg.sv
    INTERFACES
        ${CMAKE_CURRENT_SOURCE_DIR}/bus.sv
    SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/SyscallUnit.sv
)
