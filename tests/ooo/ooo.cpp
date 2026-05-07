#include <gtest/gtest.h>

#include <verilated.h>
#include <verilated_vcd_c.h>

#include "Vooo.h"
#include "Vooo__Dpi.h"
#include "Vooo___024root.h"
#include "Vooo_ooo_top_tb.h"
#include "util.hpp"

#include <cassert>
#include <cstddef>
#include <cstdio>
#include <filesystem>
#include <string>
#include <vector>

vluint64_t g_verilator_time = 0;

namespace fs = std::filesystem;

double sc_time_stamp() {
    return static_cast<double>(g_verilator_time);
}

class OooSim {
public:
    OooSim() = default;

    ~OooSim() {
        destroy();
    }

    void create(int argc, char** argv, bool trace = false) {
        destroy();

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
            tfp_->open("ooo_gtest.vcd");
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

struct RiscvTestCase {
    const char* name;
    const char* hex;
    int timeout_cycles;
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

    std::string hex_arg = std::string("+hex=") + hex_file.string();
    constexpr int timeout_cycles = 1000;

    std::vector<std::string> args_storage;
    args_storage.emplace_back("ooo_gtest");
    args_storage.emplace_back(hex_arg);

    std::vector<char*> argv;
    for (std::string& arg : args_storage) {
        argv.push_back(arg.data());
    }

    int argc = static_cast<int>(argv.size());

    sim.create(argc, argv.data(), false);

    for (int i = 0; i < timeout_cycles; ++i) {
        sim.tick();

        const int status = sim.status();

        if (status == 1) {
            SUCCEED() << hex_file.filename().stem().string() << " passed at cycle " << sim.cycle();
            return;
        }

        if (status == -1) {
            FAIL() << hex_file.filename().stem().string()
                   << " failed at cycle " << sim.cycle()
                   << ", failing test number = " << sim.a0();
        }

        if (sim.gotFinish()) {
            FAIL() << hex_file.filename().stem().string()
                   << " called $finish before pass/fail status was visible"
                   << ", cycle = " << sim.cycle()
                   << ", a0 = " << sim.a0();
        }
    }

    FAIL() << hex_file.filename().stem().string()
           << " timed out after " << timeout_cycles
           << " cycles, a0 = " << sim.a0();
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
        "rv32ui-andi.hex",
        "rv32ui-auipc.hex",
        "rv32ui-beq.hex",
        "rv32ui-bge.hex",
        "rv32ui-bgeu.hex",
        "rv32ui-blt.hex",
        "rv32ui-bltu.hex",
        "rv32ui-bne.hex",
        "rv32ui-jal.hex",
        "rv32ui-jalr.hex",
        "rv32ui-ori.hex",
        "rv32ui-sll.hex",
        "rv32ui-srl.hex",
        "rv32ui-xori.hex",
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