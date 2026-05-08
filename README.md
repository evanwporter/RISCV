# RISCV

This is not your average SLOP-V Core with 5 pipeline stages.

This one has rudimentary OoO CPU processing. Currently every instruction except `ecall` and `ebreak` are implemented. It passes the `riscv-tests` for the `rv32i` subset.

The speculative execution just predicts that every branch will not be taken.

There's a lot more information/technical details in `planning/Overview.md` (an Obsidian Vault).

The goal is to eventually be able to play DOOM.
