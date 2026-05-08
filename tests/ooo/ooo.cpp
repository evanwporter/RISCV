#include <gtest/gtest.h>

#include <verilated.h>
#include <verilated_vcd_c.h>

#include "Vooo.h"
#include "Vooo__Dpi.h"
#include "Vooo___024root.h"
#include "Vooo_ooo_top_tb.h"
#include "snapshot.hpp"
#include "util.hpp"

#include <cassert>
#include <cstddef>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

vluint64_t g_verilator_time = 0;

namespace fs = std::filesystem;

static constexpr int timeout_cycles = 1000;

double sc_time_stamp() {
    return static_cast<double>(g_verilator_time);
}

static fs::path make_failure_log_path(const fs::path& hex_file) {
    fs::path dir = fs::path { "ooo_test_logs" };
    fs::create_directories(dir);

    std::string name = hex_file.filename().stem().string();
    for (char& c : name) {
        if (!std::isalnum(static_cast<unsigned char>(c))) {
            c = '_';
        }
    }

    return dir / (name + ".log");
}

static bool g_sv_assert_failed = false;
static std::string g_sv_assert_message;

extern "C" void rv_assert_fail(const char* file, int line, const char* msg) {
    if (!g_sv_assert_failed) {
        g_sv_assert_failed = true;

        std::ostringstream oss;
        oss << "SV assertion failed at "
            << (file ? file : "<unknown>")
            << ":" << line
            << ": "
            << (msg ? msg : "<no message>");

        g_sv_assert_message = oss.str();
    }

    VL_PRINTF("[error] %s\n", g_sv_assert_message.c_str());
}

static void write_failure_log(
    const fs::path& log_path,
    const fs::path& hex_file,
    int cycle,
    int a0,
    const std::string& reason,
    const std::string& stdout_text,
    const std::string& stderr_text) {

    std::ofstream out(log_path, std::ios::out | std::ios::trunc);

    out << "Test: " << hex_file.string() << "\n";
    out << "Reason: " << reason << "\n";
    out << "Cycle: " << cycle << "\n";
    out << "a0: " << a0 << "\n";
    out << "\n";

    out << "========== STDOUT ==========\n";
    out << stdout_text << "\n";

    out << "========== STDERR ==========\n";
    out << stderr_text << "\n";
}

class OooSim {
public:
    OooSim() = default;

    ~OooSim() {
        destroy();
    }

    void create(int argc, char** argv, bool trace = true) {
        destroy();

        g_sv_assert_failed = false;
        g_sv_assert_message.clear();

        Verilated::threadContextp(nullptr);
        Verilated::gotFinish(false);
        g_verilator_time = 0;

        trace_ = trace;

        context_ = new VerilatedContext;
        context_->time(0);
        context_->commandArgs(argc, argv);
        context_->traceEverOn(trace_);

        top_ = new Vooo { context_ };

        const svScope scope = svGetScopeFromName("TOP.ooo_top_tb");
        assert(scope && "Could not find SV scope TOP.ooo_top_tb");
        svSetScope(scope);

        if (trace_) {
            tfp_ = new VerilatedVcdC;
            top_->trace(tfp_, 999);
            tfp_->open((fs::path(__FILE__).parent_path() / "ooo_gtest.vcd").string().c_str());
        }

        reset();
    }

    void destroy() {
        if (top_) {
            top_->final();
        }

        if (tfp_) {
            tfp_->close();
            delete tfp_;
            tfp_ = nullptr;
        }

        delete top_;
        top_ = nullptr;

        Verilated::threadContextp(nullptr);

        delete context_;
        context_ = nullptr;

        trace_ = false;
        g_verilator_time = 0;
        Verilated::gotFinish(false);
    }

    void reset() {
        top_->clk = 0;
        top_->reset = 1;

        context_->time(0);
        g_verilator_time = 0;
        eval_dump();

        for (int i = 0; i < 4; ++i) {
            top_->clk = !top_->clk;
            eval_dump();
        }

        top_->reset = 0;
    }

    void tick() {
        top_->clk = 1;
        eval_dump();

        top_->clk = 0;
        eval_dump();
    }

    int status() const {
        return top_->ooo_top_tb->get_test_status();
    }

    int a0() const {
        return top_->ooo_top_tb->get_a0();
    }

    int cycle() const {
        return top_->ooo_top_tb->get_cycle();
    }

    bool gotFinish() const {
        return context_->gotFinish();
    }

    CycleSnapshot get_cycle_snapshot() const {
        const auto snap = top_->ooo_top_tb->get_snapshot();
        return CycleSnapshot {
            .Fetched_PC = snap.__PVT__Fetched_PC,
            .Decoded_PC = snap.__PVT__Decoded_PC,
            .Renamed_PC = snap.__PVT__Renamed_PC,
            .Dispatched_PC = snap.__PVT__Dispatched_PC,
            .Issued_PC = snap.__PVT__Issued_PC,
            .Executed_PC = snap.__PVT__Executed_PC
        };
    }

private:
    void eval_dump() {
        top_->eval();

        if (tfp_) {
            tfp_->dump(context_->time());
        }

        context_->timeInc(5);
        g_verilator_time = context_->time();
    }

private:
    VerilatedContext* context_ = nullptr;
    Vooo* top_ = nullptr;
    VerilatedVcdC* tfp_ = nullptr;
    bool trace_ = false;
};

class RV32UITest : public ::testing::TestWithParam<fs::path> {
protected:
    void TearDown() override {
        sim.destroy();
    }

    OooSim sim;
};

TEST_P(RV32UITest, Passes) {
    const fs::path hex_file = GetParam();

    std::string hex_arg = std::string("+hex=") + hex_file.generic_string();

    std::vector<std::string> args_storage;
    args_storage.emplace_back("ooo_gtest");
    args_storage.emplace_back(hex_arg);

    std::vector<char*> argv;
    for (std::string& arg : args_storage) {
        argv.push_back(arg.data());
    }

    int argc = static_cast<int>(argv.size());

    testing::internal::CaptureStdout();
    testing::internal::CaptureStderr();

    sim.create(argc, argv.data(), true);

    bool passed = false;
    bool failed = false;
    std::string failure_reason;

    for (int i = 0; i < timeout_cycles; ++i) {
        sim.tick();

        if (g_sv_assert_failed) {
            failed = true;

            std::ostringstream oss;
            oss << hex_file.filename().stem().string()
                << " hit SV assertion at cycle " << sim.cycle()
                << ", a0 = " << sim.a0()
                << "\n"
                << g_sv_assert_message;

            failure_reason = oss.str();
            break;
        }

        struct {
            int PC[256];
            int valid[256];
            int busy[256];
        } ROB;

        struct AIQ {
            int PC[256];
            int valid[256];
            int prs1_ready[256];
            int prs2_ready[256];
        } AIQ;

        struct MIQ {
            int PC[256];
            int valid[256];
            int prs1_ready[256];
            int prs2_ready[256];
        } MIQ;

        const auto snapshot = sim.get_cycle_snapshot();

        get_rob_entries(ROB.PC, ROB.valid, ROB.busy);
        get_alu_iq_entries(AIQ.PC, AIQ.valid, AIQ.prs1_ready, AIQ.prs2_ready);
        get_mem_iq_entries(MIQ.PC, MIQ.valid, MIQ.prs1_ready, MIQ.prs2_ready);

        printf("Cycle %d: F = %d, Dc = %d, R = %d, Dp = %d, I = %d, E = %d\n", sim.cycle() + 1, snapshot.Fetched_PC, snapshot.Decoded_PC, snapshot.Renamed_PC, snapshot.Dispatched_PC, snapshot.Issued_PC, snapshot.Executed_PC);

        // print ROB
        printf("  ROB: ");
        for (int i = 0; i < 256; i++) {
            if (ROB.valid[i]) {
                printf("[%d:%d:%s] ", i, ROB.PC[i], ROB.busy[i] ? "1" : "0");
            }
        }
        printf("\n");

        // print AIQ
        printf("  AIQ: ");
        for (int i = 0; i < 256; i++) {
            if (AIQ.valid[i]) {
                printf("[%d:%d,%s,%s] ", i, AIQ.PC[i], AIQ.prs1_ready[i] ? "1" : "0", AIQ.prs2_ready[i] ? "1" : "0");
            }
        }
        printf("\n");

        // print MIQ
        printf("  MIQ: ");
        for (int i = 0; i < 256; i++) {
            if (MIQ.valid[i]) {
                printf("[%d:%d,%s,%s] ", i, MIQ.PC[i], MIQ.prs1_ready[i] ? "1" : "0", MIQ.prs2_ready[i] ? "1" : "0");
            }
        }
        printf("\n");

        const int status = sim.status();

        if (status == 1) {
            passed = true;
            break;
        }

        if (status == -1) {
            failed = true;

            std::ostringstream oss;
            oss << hex_file.filename().stem().string()
                << " failed at cycle " << sim.cycle()
                << ", failing test number = " << sim.a0();

            failure_reason = oss.str();
            break;
        }

        if (sim.gotFinish()) {
            failed = true;

            std::ostringstream oss;
            oss << hex_file.filename().stem().string()
                << " called $finish before pass/fail status was visible"
                << ", cycle = " << sim.cycle()
                << ", a0 = " << sim.a0();

            failure_reason = oss.str();
            break;
        }
    }

    if (!passed && !failed) {
        failed = true;

        std::ostringstream oss;
        oss << hex_file.filename().stem().string()
            << " timed out after " << timeout_cycles
            << " cycles, a0 = " << sim.a0();

        failure_reason = oss.str();
    }

    const std::string stdout_text = testing::internal::GetCapturedStdout();
    const std::string stderr_text = testing::internal::GetCapturedStderr();

    if (passed) {
        SUCCEED() << hex_file.filename().stem().string()
                  << " passed at cycle " << sim.cycle();
        return;
    }

    const fs::path log_path = make_failure_log_path(hex_file);

    write_failure_log(
        log_path,
        hex_file,
        sim.cycle(),
        sim.a0(),
        failure_reason,
        stdout_text,
        stderr_text);

    FAIL() << failure_reason
           << "\nLog written to: " << fs::absolute(log_path).string();
}

static const fs::path test_dir = fs::path { TEST_DIR };

static const std::vector<fs::path> custom_hex_files = collect_files_in_directory(
    test_dir / "asm" / "custom",
    ".hex",
    {});

static const std::vector<fs::path> riscv_hex_files = collect_files_in_directory(
    test_dir / "asm" / "riscv",
    ".hex",
    {
        "rv32ui-auipc.hex",
        "rv32ui-jal.hex",
        "rv32ui-jalr.hex",
    },
    "rv32ui-");

INSTANTIATE_TEST_SUITE_P(
    CustomHexFiles,
    RV32UITest,
    ::testing::ValuesIn(custom_hex_files),
    get_test_name);

INSTANTIATE_TEST_SUITE_P(
    RV32UI,
    RV32UITest,
    ::testing::ValuesIn(riscv_hex_files),
    get_test_name);

int main(int argc, char** argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}