#include "util.hpp"

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