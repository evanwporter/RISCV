#include <verilated.h>
#include <verilated_vcd_c.h>

#include "Vooo.h"
#include "Vooo__Dpi.h"
#include "Vooo___024root.h"

#include <verilated.h>

#include <filesystem>

#include "Vooo_ooo_top_tb.h"
#include "snapshot.hpp"
#include "types.hpp"

#include <fstream>
#include <rfl/json.hpp>

namespace fs = std::filesystem;

/// Global Verilator time variable
vluint64_t g_verilator_time = 0;

double sc_time_stamp() {
    return static_cast<double>(g_verilator_time);
}

extern "C" int rv_syscall(
    int syscall_num,
    int arg0,
    int arg1,
    int arg2,
    int pc,
    int* halt);

void tick(Vooo* top, VerilatedVcdC* tfp, VerilatedContext* contextp) {
    // rising edge
    top->clk = 1;
    top->eval();
    contextp->timeInc(5);
    tfp->dump(contextp->time());

    // falling edge
    top->clk = 0;
    top->eval();
    contextp->timeInc(5);
    tfp->dump(contextp->time());
}

int main(int argc, char** argv) {
    Verilated::debug(0);

    auto contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    contextp->traceEverOn(true);

    auto top = new Vooo { contextp };

    const svScope scope = svGetScopeFromName("TOP.ooo_top_tb");
    assert(scope); // Check for nullptr if scope not found
    svSetScope(scope);

    const fs::path output_dir = fs::path(__FILE__).parent_path();

    auto tfp = new VerilatedVcdC;
    top->trace(tfp, 999);
    fs::path wave_path = output_dir / "bin_top_tb.vcd";
    tfp->open(wave_path.string().c_str());

    top->clk = 0;
    top->reset = 1;

    contextp->time(0);
    top->eval();
    tfp->dump(contextp->time());

    for (int i = 0; i < 4; i++) {
        top->clk = !top->clk;
        top->eval();
        contextp->timeInc(5);
        tfp->dump(contextp->time());
    }

    top->reset = 0;

    int cycle = 0;

    const auto root = top->rootp;

    TraceFile trace_file;

    while (!contextp->gotFinish()) {
        tick(top, tfp, contextp);

        // const TraceCycle trace_cycle = collect_trace_cycle(
        //     top,
        //     static_cast<uint64_t>(cycle + 1),
        //     static_cast<uint64_t>(contextp->time()));
        // trace_file.cycles.push_back(trace_cycle);

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

        const auto snap = top->ooo_top_tb->get_snapshot();
        CycleSnapshot snapshot = {
            .Fetched_PC = snap.__PVT__Fetched_PC,
            .Decoded_PC = snap.__PVT__Decoded_PC,
            .Renamed_PC = snap.__PVT__Renamed_PC,
            .Dispatched_PC = snap.__PVT__Dispatched_PC,
            .Issued_PC = snap.__PVT__Issued_PC,
            .Executed_PC = snap.__PVT__Executed_PC
        };

        get_rob_entries(ROB.PC, ROB.valid, ROB.busy);
        get_alu_iq_entries(AIQ.PC, AIQ.valid, AIQ.prs1_ready, AIQ.prs2_ready);
        get_mem_iq_entries(MIQ.PC, MIQ.valid, MIQ.prs1_ready, MIQ.prs2_ready);

        printf("Cycle %d: F = %d, Dc = %d, R = %d, Dp = %d, I = %d, E = %d\n", cycle + 1, snapshot.Fetched_PC, snapshot.Decoded_PC, snapshot.Renamed_PC, snapshot.Dispatched_PC, snapshot.Issued_PC, snapshot.Executed_PC);

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

        cycle++;
    }

    top->final();
    tfp->close();

    // {
    //     fs::path json_path = output_dir / "ooo_trace.json";
    //     std::ofstream json_out(json_path, std::ios::out | std::ios::trunc);

    //     if (!json_out.is_open()) {
    //         fprintf(stderr, "Failed to open JSON trace file: %s\n", json_path.string().c_str());
    //     } else {
    //         json_out << rfl::json::write(trace_file) << '\n';
    //         json_out.flush();
    //         json_out.close();

    //         printf("Wrote JSON trace: %s\n", json_path.string().c_str());
    //     }
    // }

    delete tfp;
    delete top;
    delete contextp;

    return 0;
}