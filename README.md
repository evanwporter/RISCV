# RISCV

This is not your average SLOP-V Core with 5 pipeline stages.

This one has rudimentary OoO CPU processing. Currently there are 4 instructions supported `add(i)`, `sub`, `branch(eq/ne)`.

~~Even though its OoO it does not have speculative execution...yet. This means that is executes out of order up until it hits a branch instruction at which point it halts.~~
