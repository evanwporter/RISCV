33 registers
* `x0`
* `x1-x31`
* `pc`
The `x0` register is always zero.

### R-Type (Register-Register)
![[graphics/R-Type.svg|695]]
### I-Type (Immediate)
![[graphics/I-Type.svg|696]]
### S-Type (Store)
![[graphics/S-Type.svg]]
### J-Type (Jump)
![[graphics/J-Type.svg]]
### U-Type (Upper Immediate)
![[graphics/U-Type.svg]]
### B-Type (Branch)
![[graphics/B-Type.svg]]

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

A source reg in the IQ is readied when it’s written back. Its written back via the Register File. Every operand (source) in every IQ entry that is waiting on that physical register is marked ready. 

Every cycle (ie: [[Overview#Issue]] Stage) it scans every entry, and selects a limited number (based on execution ports) of ready UOPs (ready means both source registers are marked ready) to issue onto the execution unit.

## Reorder Buffer

>After instructions are _decoded_ and _renamed_, they are then _dispatched_ to the ROB and the **Issue Queue** and marked as _busy_. As instructions finish execution, they inform the ROB and are marked _not busy_. Once the “head” of the ROB is no longer busy, the instruction is _committed_, and it’s architectural state now visible. If an exception occurs and the excepting instruction is at the head of the ROB, the pipeline is flushed and no architectural changes that occurred after the excepting instruction are made visible. The ROB then redirects the PC to the appropriate exception handler.
> -[The Reorder Buffer (ROB) and the Dispatch Stage — RISCV-BOOM documentation](https://docs.boom-core.org/en/latest/sections/reorder-buffer.html)

So once the head of the ROB is no longer busy, we *commit*. This means we push the physical register to the `Free List` and we pop the entry from the buffer.

The reorder queue tracks the original order of the fetches.

When execution finishes we mark the corresponding entry in the ROB as no longer busy. Notice that this happens through the Execution Unit, and not the Register File like in the case of Issue Queue. The reason being is not every instruction writes back, but every instruction need to commit and come off the ROB, so we route through the Execution Unit.

Only a limited number of instructions are committed every cycle (ie popped off the ROB) 

---
## Load/Store Queue

> Entries in the Store Queue are allocated in the _Decode_ stage ( stq(i).valid is set). A “valid” bit denotes when an entry in the STQ holds a valid address and valid data (stq(i).bits.addr.valid and stq(i).bits.data.valid). Once a store instruction is committed, the corresponding entry in the Store Queue is marked as committed. The store is then free to be fired to the memory system at its convenience. Stores are fired to the memory in program order.
> -[The Load/Store Unit (LSU) — RISCV-BOOM documentation](https://docs.boom-core.org/en/latest/sections/load-store-unit.html#store-instructions)

> Entries in the Load Queue (LDQ) are allocated in the _Decode_ stage (`ldq(i).valid`). In **Decode**, each load entry is also given a _store mask_ (`ldq(i).bits.st\_dep\_mask`), which marks which stores in the Store Queue the given load depends on.
> -[The Load/Store Unit (LSU) — RISCV-BOOM documentation](https://docs.boom-core.org/en/latest/sections/load-store-unit.html#load-instructions)

The store Q are necessary because they ensure that the CPU executes the instruction in order. 
Every cycle it checks whether the top of the STQ has been executed. If so? Then it pops and executes the store operation (a write operation).

Popping an entry off the issue queue means marking the corresponding entry in the Load/Store Queue as ready to be executed (or at least the address or data is valid).

The Load Queue executes whenever its ready, even if that means out of order.

Entries are allocated during the decode stage (ie: pushed to the Q)

### Store Queue
Each STQ entry contains:
- `valid`
- `committed`
- `addr_valid + addr`
- `data_valid + data`

#### Lifecycle of a Store
1. **Allocation (Decode / Dispatch)**
    - Entry is allocated (`valid = 1`)
    - No address/data yet
2. **Execution (Address/Data fill)**
    - Address and data arrive independently
    - `addr_valid` and `data_valid` set when ready
3. **Commit**
    - `committed = 1` when `ROB` commits the store
4. **Fire to Memory (Strictly in-order)**
    - Only the head entry can issue to memory
    - Conditions:
        - `valid`
        - `committed`
        - `addr_valid`
        - `data_valid`    
5. **Dequeue**
    - After issuing to memory, the entry is removed


### Load Queue
Each LDQ entry contains:
- `valid`
- `addr_valid + addr`
- `pdst` (physical destination register)
- `st_dep_mask` (store dependency mask)
#### Lifecycle of a Load
1. **Allocation (Decode / Dispatch)**
    - Entry is allocated (`valid = 1`)
    - Store dependency mask is initialized to all currently valid STQ entries
    - Address and destination register not yet available
2. **Register Rename / Destination Setup**
    - Physical destination register (`pdst`) is written from RAT
3. **Execution (Address Generation)**
    - Load address is computed and written into the entry
    - `addr_valid = 1`
4. **Waiting on Store Dependencies**
    - Load cannot execute until all bits in `st_dep_mask` are cleared
    - Each bit is cleared when the corresponding store leaves the STQ (fires to memory)
    - This enforces ordering with all older stores
5. **Issue to Memory**
    - Load is eligible when:
        - `valid`
        - `addr_valid`
        - `st_dep_mask == 0`
    - Read Request is sent to memory via the `LSU`
6. **Writeback**
    - Memory response is written to the register file:
        - `rf_write_bus.en = 1`
        - `rf_write_bus.addr = pdst`
        - `rf_write_bus.data = mem_bus.rdata`
7. **Dequeue**
    - Entry is immediately invalidated after issuing to memory
    - No replay or retry mechanism

## Branch

### Lifecycle of a Branch Instruction

1. **Allocation (Decode / Dispatch)**
    - Branch is decoded and dispatched
    - ROB entry is allocated:
        - `valid = 1`
        - `busy = 1`
        - `is_branch = 1`
    - `branch_info` is initially **unresolved**
2. **Execution (Branch Resolution)**
    - Branch executes in the ALU pipeline
    - Condition is evaluated (`branch_taken`)
    - Target is computed `target = PC + imm`      
    - Mispredict is detected `mispredict = taken && (predicted_target != actual_target)`
    - Execution unit produces `branch_info`:
        - `valid = 1`
        - `rob_idx = branch ROB index`
        - `target = computed target`
        - `taken = branch outcome`
        - `mispredict = detected mismatch`
3. **Writeback to ROB**
    - ROB receives `branch_info`
    - Updates the corresponding entry:
        - `branch_info` fields written
        - `resolved = !mispredict`
            - If correct → resolved immediately
            - If mispredicted → left unresolved (will trigger flush)
4. **Oldest Branch Tracking**
    - ROB continuously scans for the oldest unresolved branch entry
    - Condition:
        - `valid`
        - `is_branch`
        - `!resolved`
        - `!flushed`
5. **Mispredict Detection -> Flush Trigger**
    - If the oldest branch is valid and is a mis predict then set PC to `branch target` and flush
6. **Flush Handling (Recovery)**
	- ROB discard all entries younger than the branch. 
	- The age is based on the `rob_index` (ie: when it entered the `ROB`)
	- IQ, LDQ, and STQ do so as well (actually atm LDQ and STQ don't but that needs to be changed).
    - All updates are blocked this cycle
    - Marks the ROB branch entry as having resolved.
	    - `resolved <= 1`
7. **Commit (In-Order Retirement)**
    - Once resolved:
        - Branch behaves like a normal instruction
    - Can commit when:
        - At ROB head
        - `!busy`
        - `resolved = 1`
    - On commit:
        - Entry is removed (`valid = 0`)
        - Head pointer advances