#include <cstdint>
#include <cstdlib>
#include <exception>
#include <iostream>
#include <string>
#include <vector>

#include "common/util.hpp"

static LoadedElf32 g_loaded_elf;
static std::size_t g_loaded_size = 0;

extern "C" void dpi_load_elf(const char* path, std::uint32_t memory_size) {
    try {
        g_loaded_elf = load_elf_segments(std::string(path), memory_size);

        g_loaded_size = g_loaded_elf.memory.size();

        std::cout << "DPI loaded ELF: " << path << "\n";
        std::cout << "  memory_base = 0x"
                  << std::hex << g_loaded_elf.memory_base << "\n";
        std::cout << "  entry_point = 0x"
                  << std::hex << g_loaded_elf.entry_point << "\n";
        std::cout << "  memory size = "
                  << std::dec << g_loaded_elf.memory.size() << " bytes\n";
    } catch (const std::exception& e) {
        std::cerr << "Failed to load ELF: " << e.what() << "\n";
        std::abort();
    }
}

extern "C" std::uint32_t dpi_get_elf_memory_base() {
    return g_loaded_elf.memory_base;
}

extern "C" std::uint32_t dpi_get_elf_entry_point() {
    return g_loaded_elf.entry_point;
}

extern "C" std::uint32_t dpi_get_elf_loaded_size() {
    return static_cast<std::uint32_t>(g_loaded_size);
}

extern "C" std::uint8_t dpi_get_elf_byte(std::uint32_t offset) {
    if (offset >= g_loaded_elf.memory.size()) {
        return 0;
    }

    return g_loaded_elf.memory[offset];
}