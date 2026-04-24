#include <verilated.h>
#include <verilated_vcd_c.h>

#include "Vbin.h"
#include "Vbin___024root.h"

#include <verilated.h>

#include <filesystem>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <vector>

namespace fs = std::filesystem;

/// Global Verilator time variable
vluint64_t g_verilator_time = 0;

double sc_time_stamp() {
    return static_cast<double>(g_verilator_time);
}

void tick(Vbin* top, VerilatedVcdC* tfp, VerilatedContext* contextp) {
    // Clock low
    top->clk = 1;
    top->eval();
    tfp->dump(contextp->time());
    contextp->timeInc(5);

    // Clock high
    top->clk = 0;
    top->eval();
    tfp->dump(contextp->time());
    contextp->timeInc(5);
}

void load_hex_into_imem(Vbin* top, const fs::path& path) {
    std::ifstream file(path);
    if (!file.is_open()) {
        VL_PRINTF("Failed to open hex file: %s\n", path.string().c_str());
        exit(1);
    }

    std::string line;
    int idx = 0;

    while (std::getline(file, line)) {
        if (line.empty())
            continue;

        uint32_t value;
        std::stringstream ss;
        ss << std::hex << line;
        ss >> value;

        top->rootp->bin_top_tb__DOT__instr_mem__DOT__mem[idx] = value;

        idx++;
    }

    VL_PRINTF("Loaded %d instructions into instruction memory\n", idx);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    auto contextp = new VerilatedContext;
    contextp->traceEverOn(true);

    auto top = new Vbin { contextp };

    // Run SV initial blocks first
    top->eval();

    load_hex_into_imem(top, "add.hex");

    auto tfp = new VerilatedVcdC;
    top->trace(tfp, 99);

    fs::path wave_path = fs::path(__FILE__).parent_path() / "bin_top_tb.vcd";
    tfp->open(wave_path.string().c_str());

    VL_PRINTF("Writing wave to: %s\n", wave_path.string().c_str());

    int max_cycles = 200;

    top->clk = 0;
    top->reset = 1;
    top->eval();
    tfp->dump(contextp->time());
    contextp->timeInc(5);

    top->clk = 1;
    top->eval();
    tfp->dump(contextp->time());
    contextp->timeInc(5);

    top->clk = 0;
    top->eval();
    tfp->dump(contextp->time());
    contextp->timeInc(5);

    top->reset = 0;

    while (!contextp->gotFinish() && contextp->time() < max_cycles * 10) {
        tick(top, tfp, contextp);

        auto root = top->rootp;

        auto regs = root->bin_top_tb__DOT__dut__DOT__rf__DOT__regs;
        auto rat = root->bin_top_tb__DOT__dut__DOT__renamer__DOT__RAT;

        uint32_t phys_idx = rat[10];
        int32_t x10 = regs[phys_idx];

        if (x10 == -1) {
            VL_PRINTF("PASS at time %llu\n", contextp->time());
            break;
        }

        if (x10 != 0 && x10 != -1) {
            VL_PRINTF("FAIL: test %d at time %llu\n", x10, contextp->time());
            break;
        }
    }

    if (!contextp->gotFinish()) {
        VL_PRINTF("TIMEOUT\n");
    }

    VL_PRINTF("TIMEOUT\n");

    top->final();

    tfp->flush();
    tfp->close();

    delete tfp;
    delete top;
    delete contextp;

    return 0;
}