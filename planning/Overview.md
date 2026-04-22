33 registers
* `x0`
* `x1-x31`
* `pc`
The `x0` register is always zero.

### R-Type (Register-Register)
![[R-Type.svg|695]]
### I-Type (Immediate)
![[I-Type.svg|696]]
### S-Type (Store)
![[S-Type.svg]]
### J-Type (Jump)
![[J-Type.svg]]
### U-Type (Upper Immediate)
![[U-Type.svg]]
### B-Type (Branch)
![[B-Type.svg]]

| Type   | Inputs   | Output |
| ------ | -------- | ------ |
| R-type | rs1, rs2 | rd     |
| I-type | rs1, imm | rd     |
| S-type | rs1, rs2 | -      |
| B-type | rs1, rs2 | -      |
| U-type | imm      | rd     |
| J-type | imm      | rd     |
## Register Renaming
- **Sources (`rs1, rs2`)**: mapped via RAT (lookup)
- **Destination (`rd`)**: gets a new physical register (allocation)

**Register Alias Table (RAT):** Maps Logical Register (`x1`) → Physical Register (`p17`)
**Free List**: A bitmask or queue that holds all the free registers. Registers are added during the commit stage, and they are removed during the rename stage.
**Busy List**: A bitmask indicating whether each physical register’s value is ready. Registers are marked busy when allocated during rename, and cleared (not busy) on writeback when the value becomes available.
## Dispatcher

The Dispatcher receives the renamed registers, and insert entries onto the ROB and the Issue Queue. When they are dispatched, the instruction is marked as busy. It becomes non-busy when the execution writes back.

## Issue Queue

There is usually one issue queue for each part of the execution. One for the ALU, one for the load/store unit, etc.

Every time a writeback of a micro-op finishes, a writeback tag is produced. This is broadcasted to all issue queues. Any entries within the IQ that depend on this register getting written back are removed from the IQ, and pushed onto the execution unit.

A source reg in the IQ is readied when it’s written back. Every operand (source) in every IQ entry that is waiting on that physical register is marked ready. 

Every cycle (ie: [[Overview#Issue]] Stage) it scans every entry, and selects a limited number (based on execution ports) of ready UOPs (ready means both source registers are marked ready) to issue onto the execution unit.

## Reorder Buffer

>After instructions are _decoded_ and _renamed_, they are then _dispatched_ to the ROB and the **Issue Queue** and marked as _busy_. As instructions finish execution, they inform the ROB and are marked _not busy_. Once the “head” of the ROB is no longer busy, the instruction is _committed_, and it’s architectural state now visible. If an exception occurs and the excepting instruction is at the head of the ROB, the pipeline is flushed and no architectural changes that occurred after the excepting instruction are made visible. The ROB then redirects the PC to the appropriate exception handler.
> -[The Reorder Buffer (ROB) and the Dispatch Stage — RISCV-BOOM documentation](https://docs.boom-core.org/en/latest/sections/reorder-buffer.html)

So once the head of the ROB is no longer busy, we *commit*. This means we push the physical register to the `Free List` and we pop the entry from the buffer.

The reorder queue tracks the original order of the fetches.

When execution finishes we mark the corresponding entry in the ROB as no longer busy.

Only a limited number of instructions are committed every cycle (ie popped off the ROB) 

## Stages

### Fetch
Instructions are fetched
-> Produced `fetched_IR`

### Decode
Decode pulls instructions out of the Fetch Buffer and generates the appropriate Micro-Op(s) (UOPs) to place into the pipeline. [2]

### Rename
The ISA, or “logical”, register specifiers (e.g. x0-x31) are then _renamed_ into “physical” register specifiers.
-> Produces `Physical Registers`

### Dispatch
Inserts instructions into IQ and ROB and Load/Store Queue (if memory operation)

### Issue
At the issue stage a configurable number of entries in the IQ are popped (if and only if these entries are ready) and sent to the execution pipeline.
Once an instruction leaves the issue queue, it flows without stopping down to writeback. Then its held at commit.
### Execute
Once an instruction is issued onto the execute unit, it goes all the way to writeback.
### Memory

### Writeback

ALU and load operations are written back to the register file. This also produces a Writeback tag which is broadcasted to the `Issue Queue`, the `ROB` and the `Renamer` Module.

Writing back also outputs a `ROB` pointer which is used too mark the corresponding Rob entry as being not busy or ready 

### Commit

We commit & pop the top instruction on the ROB for as long as the top entry is not busy.

Commit also means that the old physical register is pushed to the `Renamer` free list.

On commit the architectural map is updated to the new register (overwriting the old register) (architectural map is like the RAT but only changed by commits). 

Each stage needs to carry all the info needed for future stages (even if not needed for the current stage), but it can discard information that won’t be needed for future stages. 

### Load/Store Queue

> Entries in the Store Queue are allocated in the _Decode_ stage ( stq(i).valid is set). A “valid” bit denotes when an entry in the STQ holds a valid address and valid data (stq(i).bits.addr.valid and stq(i).bits.data.valid). Once a store instruction is committed, the corresponding entry in the Store Queue is marked as committed. The store is then free to be fired to the memory system at its convenience. Stores are fired to the memory in program order.

> Entries in the Load Queue (LDQ) are allocated in the _Decode_ stage (`ldq(i).valid`). In **Decode**, each load entry is also given a _store mask_ (`ldq(i).bits.st\_dep\_mask`), which marks which stores in the Store Queue the given load depends on.

The load and store Q are necessary because they ensure that the CPU executes the instruction in order. Every cycle it checks whether the top of the Q can be executed. If so? Then it pops and executes.
Popping an entry off the issue queue means marking the corresponding entry in the Load/Store Queue as ready to be executed.

Entries are allocated during the decode stage (ie: pushed to the Q)

#### Store Queue
Each entry in the STQ holds:
- allocated bit
- committed bit
- address valid + address
- data valid + data
- optional ROB tag / age id

A store cannot update memory until it reaches the commit/retire stage.
Reason: before commit, the instruction might still be squashed (branch mispredict, exception, etc.).
So the STQ entry goes through:
1. Allocated in Decode
2. Address + data filled (via `uopSTA`/`uopSTD` or combined)
3. Marked “committed” at ROB commit
4. Only then allowed to fire to memory (in program order)
#### Load Queue
Each load queue entry holds:
- allocated bit
- executed bit
- sleeping bit
- succeeded bit
- address valid + address
- store dependency mask
- whether result came from memory or forwarding
- optional age/ROB info

Loads still have to respect ordering dynamically
When a load executes:
It checks older stores (via store mask)
Three cases:
1. No matching store address
	- Safe → go to memory immediately
2. Match + store data ready
	- Forward data from STQ → done
3. Match + store data NOT ready
	- Load goes to sleep and retries later