#include <charconv>
#include <filesystem>
#include <fstream>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

#include "common/csv/csv.hpp"

namespace fs = std::filesystem;

struct ExpectedCommit {
    std::uint32_t pc = 0;
    std::uint32_t instr = 0;

    std::optional<int> rd;
    std::optional<std::uint32_t> rd_data;

    std::optional<std::uint32_t> store_addr;
    std::optional<std::uint32_t> store_data;

    std::string instr_str;
};

static std::vector<ExpectedCommit> g_expected_commits;
static std::size_t g_expected_commit_index = 0;

static bool g_commit_compare_failed = false;
static std::string g_commit_compare_message;

static std::uint32_t parse_hex_u32(std::string s) {
    if (s.starts_with("0x") || s.starts_with("0X")) {
        s = s.substr(2);
    }

    std::uint32_t value = 0;
    auto* begin = s.data();
    auto* end = s.data() + s.size();

    auto result = std::from_chars(begin, end, value, 16);
    if (result.ec != std::errc {}) {
        throw std::runtime_error("Failed to parse hex value: " + s);
    }

    return value;
}

static int parse_register(std::string s) {
    if (s.empty()) {
        throw std::runtime_error("Empty register string");
    }

    if (s[0] == 'x') {
        s = s.substr(1);
    }

    return std::stoi(s);
}

static std::optional<std::uint32_t> parse_optional_hex_u32(const std::string& s) {
    if (s.empty()) {
        return std::nullopt;
    }

    return parse_hex_u32(s);
}

struct ParsedMemField {
    std::uint32_t addr = 0;
    std::optional<std::uint32_t> data;
};

static ParsedMemField parse_mem_field(const std::string& s) {
    const std::size_t colon = s.find(':');

    if (colon == std::string::npos) {
        return ParsedMemField {
            .addr = parse_hex_u32(s),
            .data = std::nullopt,
        };
    }

    return ParsedMemField {
        .addr = parse_hex_u32(s.substr(0, colon)),
        .data = parse_hex_u32(s.substr(colon + 1)),
    };
}

static std::vector<ExpectedCommit> load_expected_commits_csv(const fs::path& csv_path) {
    std::ifstream in(csv_path);
    if (!in) {
        throw std::runtime_error("Could not open expected commit CSV: " + csv_path.string());
    }

    const auto table = readCSV(in);

    std::vector<ExpectedCommit> commits;

    if (table.empty()) {
        throw std::runtime_error("CSV is empty: " + csv_path.string());
    }

    for (std::size_t row_idx = 1; row_idx < table.size(); ++row_idx) {
        const auto& row = table[row_idx];

        // Expected columns:
        // 0 pc
        // 1 instr mnemonic
        // 2 gpr
        // 3 csr
        // 4 mem
        // 5 binary
        // 6 mode
        // 7 instr_str
        // 8 operand
        // 9 rd
        if (row.size() < 10) {
            continue;
        }

        if (row[0].empty() || row[5].empty()) {
            continue;
        }

        ExpectedCommit commit;
        commit.pc = parse_hex_u32(row[0]);
        commit.instr = parse_hex_u32(row[5]);
        commit.instr_str = row[7];

        if (!row[9].empty()) {
            commit.rd = parse_register(row[9]);
        }

        if (!row[2].empty()) {
            commit.rd_data = parse_hex_u32(row[2]);
        }

        if (!row[4].empty()) {
            const auto [addr, data] = parse_mem_field(row[4]);
            commit.store_addr = addr;
            commit.store_data = data;
        }

        commits.push_back(commit);
    }

    return commits;
}