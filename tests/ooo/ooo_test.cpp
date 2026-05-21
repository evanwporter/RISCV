#include <gtest/gtest.h>

#include <verilated.h>
#include <verilated_vcd_c.h>

#include "Vooo.h"
#include "Vooo__Dpi.h"
#include "Vooo___024root.h"
#include "Vooo_ooo_top_tb.h"

#include "commit.hpp"
#include "common/csv/csv.hpp"
#include "common/util.hpp"

#include "dpi.hpp"
#include "snapshot.hpp"

#include <cassert>
#include <cctype>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

vluint64_t g_verilator_time = 0;

namespace fs = std::filesystem;

static constexpr int timeout_cycles = 1000;

static constexpr int ROB_WIDTH_TB = 256;
static constexpr int IQ_WIDTH_TB = 256;

static const fs::path test_dir = fs::path { TEST_DIR };
static const fs::path rv32ui_dir = fs::path { "/home/evanw/RISCV/build/rv32ui" };

double sc_time_stamp() {
    return static_cast<double>(g_verilator_time);
}

static fs::path make_failure_log_path(const fs::path& elf_file) {
    fs::path dir = fs::path { "ooo_test_logs" };
    fs::create_directories(dir);

    std::string name = elf_file.filename().stem().string();
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
    const fs::path& elf_file,
    int cycle,
    int a0,
    const std::string& reason,
    const std::string& stdout_text,
    const std::string& stderr_text) {

    std::ofstream out(log_path, std::ios::out | std::ios::trunc);

    out << "Test: " << elf_file.string() << "\n";
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

    uint64_t time() const {
        return context_->time();
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

static std::ofstream g_commit_log;
static fs::path g_commit_log_path;
static constexpr std::uint32_t TOHOST_ADDR = 0x80000000u;

//  0 = still running
//  1 = pass
// -1 = fail
static int g_tohost_status = 0;

static std::uint32_t g_tohost_value = 0;

extern "C" unsigned int on_commit(
    unsigned int PC,
    unsigned int IR,
    unsigned int rd,
    unsigned int rd_data,
    unsigned int ls_addr,
    unsigned int st_data) {

    if (g_commit_log.is_open()) {
        g_commit_log
            << "commit"
            << " index=" << std::dec << g_expected_commit_index
            << " pc=0x" << std::hex << PC
            << " ir=0x" << IR
            << " rd=x" << std::dec << rd
            << " rd_data=0x" << std::hex << rd_data
            << " ls_addr=0x" << ls_addr
            << " st_data=0x" << st_data
            << std::dec
            << "\n";
    }

    if (g_commit_compare_failed) {
        return 0;
    }

    if (g_expected_commit_index >= g_expected_commits.size()) {
        std::ostringstream oss;
        oss << "Unexpected extra commit at index " << g_expected_commit_index
            << ": pc=0x" << std::hex << PC
            << " ir=0x" << IR;

        g_commit_compare_failed = true;
        g_commit_compare_message = oss.str();
        return 0;
    }

    const ExpectedCommit& expected = g_expected_commits[g_expected_commit_index];

    auto fail = [&](const std::string& what) {
        std::ostringstream oss;

        oss << "Commit mismatch at index " << std::dec << g_expected_commit_index
            << "\n  expected pc=0x" << std::hex << expected.pc
            << " ir=0x" << expected.instr
            << "\n  actual   pc=0x" << PC
            << " ir=0x" << IR
            << "\n  expected instr: " << expected.instr_str
            << "\n  mismatch: " << what;

        g_commit_compare_failed = true;
        g_commit_compare_message = oss.str();
    };

    if (PC != expected.pc) {
        std::ostringstream oss;
        oss << "PC expected 0x" << std::hex << expected.pc
            << ", got 0x" << PC;
        fail(oss.str());
        return 0;
    }

    if (IR != expected.instr) {
        std::ostringstream oss;
        oss << "IR expected 0x" << std::hex << expected.instr
            << ", got 0x" << IR;
        fail(oss.str());
        return 0;
    }

    if (expected.rd && expected.rd_data) {
        if (rd != static_cast<unsigned int>(*expected.rd)) {
            std::ostringstream oss;
            oss << "rd expected x" << std::dec << *expected.rd
                << ", got x" << rd;
            fail(oss.str());
            return 0;
        }

        if (rd_data != *expected.rd_data) {
            std::ostringstream oss;
            oss << "rd_data expected 0x" << std::hex << *expected.rd_data
                << ", got 0x" << rd_data;
            fail(oss.str());
            return 0;
        }
    }

    if (expected.store_addr && expected.store_data) {
        if (ls_addr != *expected.store_addr) {
            std::ostringstream oss;
            oss << "store addr expected 0x" << std::hex << *expected.store_addr
                << ", got 0x" << ls_addr;
            fail(oss.str());
            return 0;
        }

        if (st_data != *expected.store_data) {
            std::ostringstream oss;
            oss << "store data expected 0x" << std::hex << *expected.store_data
                << ", got 0x" << st_data;
            fail(oss.str());
            return 0;
        }
    }

    if (ls_addr == TOHOST_ADDR && st_data != 0) {
        g_tohost_value = st_data;

        if (st_data == 1 || st_data == 0xffffffffu) {
            g_tohost_status = 1; // pass
        } else {
            g_tohost_status = -1; // fail
        }
    }

    ++g_expected_commit_index;
    return 0;
}

static void run_ooo_test(const fs::path& elf_file) {
    OooSim sim;

    g_tohost_status = 0;
    g_tohost_value = 0;

    fs::path csv_name = elf_file.filename();
    csv_name.replace_extension(".spike.csv");

    fs::path csv_file = test_dir / "golden" / csv_name;

    g_expected_commits = load_expected_commits_csv(csv_file);
    g_expected_commit_index = 0;
    g_commit_compare_failed = false;
    g_commit_compare_message.clear();

    std::string elf_arg = std::string("+elf=") + elf_file.generic_string();

    std::vector<std::string> args_storage;
    args_storage.emplace_back("ooo_gtest");
    args_storage.emplace_back(elf_arg);

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

    g_commit_log.open("test.log", std::ios::out | std::ios::trunc);
    assert(g_commit_log.is_open() && "Failed to open commit log");

    for (int i = 0; i < timeout_cycles; ++i) {
        sim.tick();

        if (g_sv_assert_failed) {
            failed = true;

            std::ostringstream oss;
            oss << elf_file.filename().stem().string()
                << " hit SV assertion at cycle " << sim.cycle()
                << ", a0 = " << sim.a0()
                << "\n"
                << g_sv_assert_message;

            failure_reason = oss.str();
            break;
        }

        struct {
            int PC[ROB_WIDTH_TB];
            int valid[ROB_WIDTH_TB];
            int busy[ROB_WIDTH_TB];
        } ROB;

        struct AIQ {
            int PC[IQ_WIDTH_TB];
            int valid[IQ_WIDTH_TB];
            int prs1_ready[IQ_WIDTH_TB];
            int prs2_ready[IQ_WIDTH_TB];
        } AIQ;

        struct MIQ {
            int PC[IQ_WIDTH_TB];
            int valid[IQ_WIDTH_TB];
            int prs1_ready[IQ_WIDTH_TB];
            int prs2_ready[IQ_WIDTH_TB];
        } MIQ;

        const auto snapshot = sim.get_cycle_snapshot();

        get_rob_entries(ROB.PC, ROB.valid, ROB.busy);
        get_alu_iq_entries(AIQ.PC, AIQ.valid, AIQ.prs1_ready, AIQ.prs2_ready);
        get_mem_iq_entries(MIQ.PC, MIQ.valid, MIQ.prs1_ready, MIQ.prs2_ready);

        printf(
            "[%lu] Cycle %d: F = %d, Dc = %d, R = %d, Dp = %d, I = %d, E = %d\n",
            static_cast<unsigned long>(sim.time()),
            sim.cycle() + 1,
            snapshot.Fetched_PC,
            snapshot.Decoded_PC,
            snapshot.Renamed_PC,
            snapshot.Dispatched_PC,
            snapshot.Issued_PC,
            snapshot.Executed_PC);

        printf("  ROB: ");
        for (int j = 0; j < ROB_WIDTH_TB; j++) {
            if (ROB.valid[j]) {
                printf(
                    "[%d:0x%08x:%s] ",
                    j,
                    static_cast<uint32_t>(ROB.PC[j]),
                    ROB.busy[j] ? "1" : "0");
            }
        }
        printf("\n");

        printf("  AIQ: ");
        for (int j = 0; j < IQ_WIDTH_TB; j++) {
            if (AIQ.valid[j]) {
                printf(
                    "[%d:0x%08x,%s,%s] ",
                    j,
                    static_cast<uint32_t>(AIQ.PC[j]),
                    AIQ.prs1_ready[j] ? "1" : "0",
                    AIQ.prs2_ready[j] ? "1" : "0");
            }
        }
        printf("\n");

        printf("  MIQ: ");
        for (int j = 0; j < IQ_WIDTH_TB; j++) {
            if (MIQ.valid[j]) {
                printf(
                    "[%d:0x%08x,%s,%s] ",
                    j,
                    static_cast<uint32_t>(MIQ.PC[j]),
                    MIQ.prs1_ready[j] ? "1" : "0",
                    MIQ.prs2_ready[j] ? "1" : "0");
            }
        }
        printf("\n");

        const int status = sim.status();

        if (g_commit_compare_failed) {
            failed = true;
            failure_reason = g_commit_compare_message;
            break;
        }

        if (g_tohost_status == 1) {
            passed = true;
            break;
        }

        if (g_tohost_status == -1) {
            failed = true;

            std::ostringstream oss;
            oss << elf_file.filename().stem().string()
                << " failed via tohost at cycle " << sim.cycle()
                << ", tohost value = 0x" << std::hex << g_tohost_value;

            failure_reason = oss.str();
            break;
        }

        if (status == 1) {
            passed = true;
            break;
        }

        if (status == -1) {
            failed = true;

            std::ostringstream oss;
            oss << elf_file.filename().stem().string()
                << " failed at cycle " << sim.cycle()
                << ", failing test number = " << sim.a0();

            failure_reason = oss.str();
            break;
        }

        if (sim.gotFinish()) {
            failed = true;

            std::ostringstream oss;
            oss << elf_file.filename().stem().string()
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
        oss << elf_file.filename().stem().string()
            << " timed out after " << timeout_cycles
            << " cycles, a0 = " << sim.a0()
            << ", tohost_status = " << g_tohost_status
            << ", tohost_value = 0x" << std::hex << g_tohost_value;

        failure_reason = oss.str();
    }

    const std::string stdout_text = testing::internal::GetCapturedStdout();
    const std::string stderr_text = testing::internal::GetCapturedStderr();

    g_commit_log.close();

    if (passed) {
        SUCCEED() << elf_file.filename().stem().string()
                  << " passed at cycle " << sim.cycle();
        return;
    }

    const fs::path log_path = make_failure_log_path(elf_file);

    write_failure_log(
        log_path,
        elf_file,
        sim.cycle(),
        sim.a0(),
        failure_reason,
        stdout_text,
        stderr_text);

    FAIL() << failure_reason
           << "\nLog written to: " << fs::absolute(log_path).string();
}

TEST(RV32UI, add) {
    run_ooo_test(rv32ui_dir / "rv32ui-add.elf");
}

TEST(RV32UI, addi) {
    run_ooo_test(rv32ui_dir / "rv32ui-addi.elf");
}

TEST(RV32UI, and) {
    run_ooo_test(rv32ui_dir / "rv32ui-and.elf");
}

TEST(RV32UI, andi) {
    run_ooo_test(rv32ui_dir / "rv32ui-andi.elf");
}

TEST(RV32UI, auipc) {
    run_ooo_test(rv32ui_dir / "rv32ui-auipc.elf");
}

TEST(RV32UI, beq) {
    run_ooo_test(rv32ui_dir / "rv32ui-beq.elf");
}

TEST(RV32UI, bge) {
    run_ooo_test(rv32ui_dir / "rv32ui-bge.elf");
}

TEST(RV32UI, bgeu) {
    run_ooo_test(rv32ui_dir / "rv32ui-bgeu.elf");
}

TEST(RV32UI, blt) {
    run_ooo_test(rv32ui_dir / "rv32ui-blt.elf");
}

TEST(RV32UI, bltu) {
    run_ooo_test(rv32ui_dir / "rv32ui-bltu.elf");
}

TEST(RV32UI, bne) {
    run_ooo_test(rv32ui_dir / "rv32ui-bne.elf");
}

TEST(RV32UI, jal) {
    run_ooo_test(rv32ui_dir / "rv32ui-jal.elf");
}

TEST(RV32UI, jalr) {
    run_ooo_test(rv32ui_dir / "rv32ui-jalr.elf");
}

TEST(RV32UI, lb) {
    run_ooo_test(rv32ui_dir / "rv32ui-lb.elf");
}

TEST(RV32UI, lbu) {
    run_ooo_test(rv32ui_dir / "rv32ui-lbu.elf");
}

TEST(RV32UI, ld_st) {
    run_ooo_test(rv32ui_dir / "rv32ui-ld_st.elf");
}

TEST(RV32UI, lh) {
    run_ooo_test(rv32ui_dir / "rv32ui-lh.elf");
}

TEST(RV32UI, lhu) {
    run_ooo_test(rv32ui_dir / "rv32ui-lhu.elf");
}

TEST(RV32UI, lui) {
    run_ooo_test(rv32ui_dir / "rv32ui-lui.elf");
}

TEST(RV32UI, lw) {
    run_ooo_test(rv32ui_dir / "rv32ui-lw.elf");
}

TEST(RV32UI, ma_data) {
    run_ooo_test(rv32ui_dir / "rv32ui-ma_data.elf");
}

TEST(RV32UI, or) {
    run_ooo_test(rv32ui_dir / "rv32ui-or.elf");
}

TEST(RV32UI, ori) {
    run_ooo_test(rv32ui_dir / "rv32ui-ori.elf");
}

TEST(RV32UI, sb) {
    run_ooo_test(rv32ui_dir / "rv32ui-sb.elf");
}

TEST(RV32UI, sh) {
    run_ooo_test(rv32ui_dir / "rv32ui-sh.elf");
}

TEST(RV32UI, simple) {
    run_ooo_test(rv32ui_dir / "rv32ui-simple.elf");
}

TEST(RV32UI, sll) {
    run_ooo_test(rv32ui_dir / "rv32ui-sll.elf");
}

TEST(RV32UI, slli) {
    run_ooo_test(rv32ui_dir / "rv32ui-slli.elf");
}

TEST(RV32UI, slt) {
    run_ooo_test(rv32ui_dir / "rv32ui-slt.elf");
}

TEST(RV32UI, slti) {
    run_ooo_test(rv32ui_dir / "rv32ui-slti.elf");
}

TEST(RV32UI, sltiu) {
    run_ooo_test(rv32ui_dir / "rv32ui-sltiu.elf");
}

TEST(RV32UI, sltu) {
    run_ooo_test(rv32ui_dir / "rv32ui-sltu.elf");
}

TEST(RV32UI, sra) {
    run_ooo_test(rv32ui_dir / "rv32ui-sra.elf");
}

TEST(RV32UI, srai) {
    run_ooo_test(rv32ui_dir / "rv32ui-srai.elf");
}

TEST(RV32UI, srl) {
    run_ooo_test(rv32ui_dir / "rv32ui-srl.elf");
}

TEST(RV32UI, srli) {
    run_ooo_test(rv32ui_dir / "rv32ui-srli.elf");
}

TEST(RV32UI, st_ld) {
    run_ooo_test(rv32ui_dir / "rv32ui-st_ld.elf");
}

TEST(RV32UI, sub) {
    run_ooo_test(rv32ui_dir / "rv32ui-sub.elf");
}

TEST(RV32UI, sw) {
    run_ooo_test(rv32ui_dir / "rv32ui-sw.elf");
}

TEST(RV32UI, xor) {
    run_ooo_test(rv32ui_dir / "rv32ui-xor.elf");
}

TEST(RV32UI, xori) {
    run_ooo_test(rv32ui_dir / "rv32ui-xori.elf");
}

int main(int argc, char** argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}