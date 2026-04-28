#pragma once

#include "types.hpp"

struct CycleSnapshot {
    u32 Fetched_PC;

    u32 Decoded_PC;

    u32 Renamed_PC;

    u32 Dispatched_PC;

    u32 Issued_PC;

    u32 Executed_PC;
};