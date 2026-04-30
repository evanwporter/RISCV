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
