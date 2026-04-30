# RISCV

This is not your average SLOP-V Core with 5 pipeline stages.

This one has rudimentary OoO CPU processing. Currently there are only a few instructions supported `alu`, `branch(eq/ne)`, and `lw`/`sw`. See `tests/asm` for more info.

The speculative execution just predicts that every branch will not be taken.

There's a lot more information/technical details in `planning/Overview.md` (an Obsidian Vault)
