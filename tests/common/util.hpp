#pragma once

#include <filesystem>
#include <string>
#include <unordered_set>
#include <vector>

#include <gtest/gtest.h>

#include "elf/elf.hpp"

std::vector<std::filesystem::path> collect_files_in_directory(
    const std::filesystem::path& dir,
    const std::string& extension,
    const std::unordered_set<std::string> exclude = {},
    const std::string& prefix = "");

std::string get_test_name(const ::testing::TestParamInfo<std::filesystem::path>& info);

struct LoadedElf32 {
    std::vector<std::uint8_t> memory;
    Elf32_Addr entry_point;
    Elf32_Addr memory_base;
};

LoadedElf32 load_elf_segments(
    const std::string& path,
    Elf32_Addr memory_base = 0x80000000,
    std::size_t memory_size = 128 * 1024 * 1024);