cmake_minimum_required(VERSION 3.20)

project(RISCV_DOOM LANGUAGES C CXX ASM)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(RISCV_ARCH rv32imac CACHE STRING "RISC-V ISA")
set(RISCV_ABI ilp32 CACHE STRING "RISC-V ABI")

set(COMMON_COMPILE_OPTIONS
    -march=${RISCV_ARCH}
    -mabi=${RISCV_ABI}
    -ffreestanding
    -fno-builtin
    -fdata-sections
    -ffunction-sections
    -Wall
    -Wextra
)

set(COMMON_LINK_OPTIONS
    -march=${RISCV_ARCH}
    -mabi=${RISCV_ABI}
    # -T${CMAKE_CURRENT_SOURCE_DIR}/linker.ld
    -nostartfiles
    -Wl,--gc-sections
    # -Wl,-Map=bf.map
)

add_library(libsyscall STATIC
    ${CMAKE_CURRENT_SOURCE_DIR}/syscall.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/syscall.s
)

target_compile_options(libsyscall PRIVATE
    ${COMMON_COMPILE_OPTIONS}
    -fno-exceptions
    -fno-rtti
)

add_executable(bf.elf)

target_compile_options(bf.elf PRIVATE
    ${COMMON_COMPILE_OPTIONS}
)

target_sources(bf.elf PRIVATE
    bf.s
)

target_include_directories(bf.elf PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_options(bf.elf PRIVATE
    ${COMMON_LINK_OPTIONS}
)

target_link_libraries(bf.elf PRIVATE
    libsyscall
    m
    c
    gcc
)

add_custom_command(TARGET bf.elf POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O binary bf.elf bf.bin
    COMMAND ${CMAKE_OBJDUMP} -d bf.elf > bf.dump
    COMMENT "Generating bf.bin and bf.dump"
)