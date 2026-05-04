#pragma once

#include "Vooo.h"
#include "types.hpp"
#include <vector>

struct CycleSnapshot {
    u32 Fetched_PC;

    u32 Decoded_PC;

    u32 Renamed_PC;

    u32 Dispatched_PC;

    u32 Issued_PC;

    u32 Executed_PC;
};

extern "C" void get_rename_debug(
    int* valid,
    int* pc,
    int* rs1_arch,
    int* rs2_arch,
    int* rd_arch,
    int* ps1,
    int* ps2,
    int* pd_old,
    int* pd_new,
    int* ps1_ready,
    int* ps2_ready,
    int* is_load,
    int* is_store,
    int* is_branch,
    int* rob_idx,
    int* stq_idx,
    int* ldq_idx,
    int watch_arch[6],
    int watch_phys[6],
    int watch_ready[6],
    int watch_busy[6]);

extern "C" void get_rob_entries(
    int pc[32],
    int valid[32],
    int busy[32]);

extern "C" void get_alu_iq_entries(
    int pc[32],
    int valid[32],
    int prs1_ready[32],
    int prs2_ready[32]);

extern "C" void get_mem_iq_entries(
    int pc[32],
    int valid[32],
    int prs1_ready[32],
    int prs2_ready[32]);

struct RatWatchSnap {
    uint32_t arch = 0; // Architectural register, e.g. x3
    uint32_t phys = 0; // Current physical mapping, e.g. P34
    bool ready = false; // !busy_list[phys]
    bool busy = false; // busy_list[phys]
};

struct RenameSnap {
    bool valid = false;
    uint32_t pc = 0;

    // Architectural source/destination registers from the uop.
    uint32_t rs1_arch = 0;
    uint32_t rs2_arch = 0;
    uint32_t rd_arch = 0;

    // Physical source/destination registers from rat_out.
    uint32_t ps1 = 0;
    uint32_t ps2 = 0;
    uint32_t pd_old = 0;
    uint32_t pd_new = 0;

    // Source readiness as seen by rename.
    bool ps1_ready = false;
    bool ps2_ready = false;

    // Instruction class.
    bool is_load = false;
    bool is_store = false;
    bool is_branch = false;

    // Queue/ROB indices associated with this renamed instruction.
    uint32_t rob_idx = 0;
    uint32_t stq_idx = 0;
    uint32_t ldq_idx = 0;

    // Selected architectural register mappings to track every cycle.
    // For ls.s: x1, x2, x3, x4, x10, x31.
    std::vector<RatWatchSnap> watch;
};

struct RobEntrySnap {
    uint32_t idx = 0;
    uint32_t pc = 0;
    bool valid = false;
    bool busy = false;
};

struct RobSnap {
    std::vector<RobEntrySnap> entries;
};

struct IqEntrySnap {
    uint32_t idx = 0;
    uint32_t pc = 0;
    bool valid = false;
    bool prs1_ready = false;
    bool prs2_ready = false;
};

struct QueueSnap {
    std::vector<IqEntrySnap> entries;
};

struct TraceCycle {
    uint64_t cycle = 0;
    uint64_t sim_time = 0;

    CycleSnapshot pipeline;

    RenameSnap rename;

    RobSnap rob;
    QueueSnap aiq;
    QueueSnap miq;
};

inline RenameSnap collect_rename(Vooo* top) {
    RenameSnap r;

    int valid = 0;
    int pc = 0;
    int rs1_arch = 0;
    int rs2_arch = 0;
    int rd_arch = 0;
    int ps1 = 0;
    int ps2 = 0;
    int pd_old = 0;
    int pd_new = 0;
    int ps1_ready = 0;
    int ps2_ready = 0;
    int is_load = 0;
    int is_store = 0;
    int is_branch = 0;
    int rob_idx = 0;
    int stq_idx = 0;
    int ldq_idx = 0;
    int watch_arch[6] = {};
    int watch_phys[6] = {};
    int watch_ready[6] = {};
    int watch_busy[6] = {};

    get_rename_debug(
        &valid,
        &pc,
        &rs1_arch,
        &rs2_arch,
        &rd_arch,
        &ps1,
        &ps2,
        &pd_old,
        &pd_new,
        &ps1_ready,
        &ps2_ready,
        &is_load,
        &is_store,
        &is_branch,
        &rob_idx,
        &stq_idx,
        &ldq_idx,
        watch_arch,
        watch_phys,
        watch_ready,
        watch_busy);

    r.valid = valid != 0;
    r.pc = static_cast<uint32_t>(pc);

    r.rs1_arch = static_cast<uint32_t>(rs1_arch);
    r.rs2_arch = static_cast<uint32_t>(rs2_arch);
    r.rd_arch = static_cast<uint32_t>(rd_arch);

    r.ps1 = static_cast<uint32_t>(ps1);
    r.ps2 = static_cast<uint32_t>(ps2);
    r.pd_old = static_cast<uint32_t>(pd_old);
    r.pd_new = static_cast<uint32_t>(pd_new);

    r.ps1_ready = ps1_ready != 0;
    r.ps2_ready = ps2_ready != 0;

    r.is_load = is_load != 0;
    r.is_store = is_store != 0;
    r.is_branch = is_branch != 0;

    r.rob_idx = static_cast<uint32_t>(rob_idx);
    r.stq_idx = static_cast<uint32_t>(stq_idx);
    r.ldq_idx = static_cast<uint32_t>(ldq_idx);

    for (int i = 0; i < 6; ++i) {
        RatWatchSnap w;
        w.arch = static_cast<uint32_t>(watch_arch[i]);
        w.phys = static_cast<uint32_t>(watch_phys[i]);
        w.ready = watch_ready[i] != 0;
        w.busy = watch_busy[i] != 0;
        r.watch.push_back(w);
    }

    (void)top;
    return r;
}

inline RobSnap collect_rob() {
    int pc[32] = {};
    int valid[32] = {};
    int busy[32] = {};

    get_rob_entries(pc, valid, busy);

    RobSnap rob;
    rob.entries.reserve(32);

    for (uint32_t i = 0; i < 32; ++i) {
        if (!valid[i]) {
            continue;
        }

        RobEntrySnap e;
        e.idx = i;
        e.pc = static_cast<uint32_t>(pc[i]);
        e.valid = valid[i] != 0;
        e.busy = busy[i] != 0;

        rob.entries.push_back(e);
    }

    return rob;
}

inline QueueSnap collect_aiq() {
    int pc[32] = {};
    int valid[32] = {};
    int prs1_ready[32] = {};
    int prs2_ready[32] = {};

    get_alu_iq_entries(pc, valid, prs1_ready, prs2_ready);

    QueueSnap q;
    q.entries.reserve(32);

    for (uint32_t i = 0; i < 32; ++i) {
        if (!valid[i]) {
            continue;
        }

        IqEntrySnap e;
        e.idx = i;
        e.pc = static_cast<uint32_t>(pc[i]);
        e.valid = valid[i] != 0;
        e.prs1_ready = prs1_ready[i] != 0;
        e.prs2_ready = prs2_ready[i] != 0;

        q.entries.push_back(e);
    }

    return q;
}

inline QueueSnap collect_miq() {
    int pc[32] = {};
    int valid[32] = {};
    int prs1_ready[32] = {};
    int prs2_ready[32] = {};

    get_mem_iq_entries(pc, valid, prs1_ready, prs2_ready);

    QueueSnap q;
    q.entries.reserve(32);

    for (uint32_t i = 0; i < 32; ++i) {
        if (!valid[i]) {
            continue;
        }

        IqEntrySnap e;
        e.idx = i;
        e.pc = static_cast<uint32_t>(pc[i]);
        e.valid = valid[i] != 0;
        e.prs1_ready = prs1_ready[i] != 0;
        e.prs2_ready = prs2_ready[i] != 0;

        q.entries.push_back(e);
    }

    return q;
}

inline CycleSnapshot collect_pipeline_snapshot(Vooo* top) {
    const auto snap = top->ooo_top_tb->get_snapshot();

    CycleSnapshot snapshot = {
        .Fetched_PC = snap.__PVT__Fetched_PC,
        .Decoded_PC = snap.__PVT__Decoded_PC,
        .Renamed_PC = snap.__PVT__Renamed_PC,
        .Dispatched_PC = snap.__PVT__Dispatched_PC,
        .Issued_PC = snap.__PVT__Issued_PC,
        .Executed_PC = snap.__PVT__Executed_PC,
    };

    return snapshot;
}

inline TraceCycle collect_trace_cycle(
    Vooo* top,
    uint64_t cycle,
    uint64_t sim_time) {
    TraceCycle t;

    t.cycle = cycle;
    t.sim_time = sim_time;

    t.pipeline = collect_pipeline_snapshot(top);
    t.rename = collect_rename(top);

    t.rob = collect_rob();
    t.aiq = collect_aiq();
    t.miq = collect_miq();

    return t;
}

struct TraceFile {
    std::string format = "ooo_trace";
    uint32_t version = 1;
    std::vector<TraceCycle> cycles;
};