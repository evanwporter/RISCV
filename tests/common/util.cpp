#include "./util.hpp"

#include <filesystem>
#include <fstream>
#include <vector>

namespace fs = std::filesystem;

std::vector<fs::path> collect_files_in_directory(
    const fs::path& dir,
    const std::string& extension,
    const std::unordered_set<std::string> exclude,
    const std::string& prefix) {

    std::vector<fs::path> roms;

    if (!fs::exists(dir) || !fs::is_directory(dir))
        return roms;

    for (const auto& entry : fs::directory_iterator(dir)) {
        if (!entry.is_regular_file())
            continue;

        if (entry.path().extension() == extension) {
            const std::string filename = entry.path().filename().string();

            if (exclude.find(filename) != exclude.end())
                continue;
            if (!prefix.empty() && !filename.starts_with(prefix))
                continue;
            roms.push_back(entry.path());
        }
    }

    std::sort(roms.begin(), roms.end());

    return roms;
}

std::string get_test_name(const ::testing::TestParamInfo<std::filesystem::path>& info) {
    std::string name = info.param.filename().stem().string();

    // GTest test names must be valid C identifiers
    for (char& c : name) {
        if (!std::isalnum(static_cast<unsigned char>(c)))
            c = '_';
    }

    return name;
};

static inline Elf32_Addr segment_load_addr(const Elf32_Phdr& phdr) {
    return phdr.p_paddr != 0 ? phdr.p_paddr : phdr.p_vaddr;
}

LoadedElf32 load_elf_segments(const std::string& path, Elf32_Addr memory_base, std::size_t memory_size) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        throw std::runtime_error("Could not open ELF file: " + path);
    }

    Elf32_Ehdr ehdr = read_elf32_header(file);

    if (ehdr.e_machine != ElfMachine::RiscV) {
        throw std::runtime_error("ELF file is not RISC-V");
    }

    std::vector<Elf32_Phdr> phdrs = read_program_headers(file, ehdr);

    std::vector<std::uint8_t> memory(memory_size, 0);

    for (const Elf32_Phdr& phdr : phdrs) {
        if (phdr.p_type != ElfProgramType::Load) {
            continue;
        }

        if (phdr.p_memsz < phdr.p_filesz) {
            throw std::runtime_error("Invalid ELF segment: p_memsz < p_filesz");
        }

        Elf32_Addr load_addr = segment_load_addr(phdr);

        if (load_addr < memory_base) {
            throw std::runtime_error("ELF segment load address is below memory base");
        }

        std::size_t mem_offset = static_cast<std::size_t>(load_addr - memory_base);

        if (mem_offset + phdr.p_memsz > memory.size()) {
            throw std::runtime_error("ELF segment does not fit in emulated memory");
        }

        file.seekg(phdr.p_offset, std::ios::beg);
        if (!file) {
            throw std::runtime_error("Failed to seek to ELF segment");
        }

        file.read(
            reinterpret_cast<char*>(memory.data() + mem_offset),
            phdr.p_filesz);

        if (!file) {
            throw std::runtime_error("Failed to read ELF segment");
        }

        // The vector was already initialized to zero, so this is technically
        // redundant, but explicit zero-fill makes the ELF rule obvious.
        std::fill(
            memory.begin() + mem_offset + phdr.p_filesz,
            memory.begin() + mem_offset + phdr.p_memsz,
            0);
    }

    return LoadedElf32 {
        .memory = std::move(memory),
        .entry_point = ehdr.e_entry,
        .memory_base = memory_base,
    };
}