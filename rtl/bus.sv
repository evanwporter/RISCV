import riscv_regs_types_pkg::*;
import riscv_rob_types_pkg::*;
import riscv_iq_types_pkg::*;
import riscv_types_pkg::*;
import riscv_decoder_types_pkg::*;
import riscv_constants_pkg::*;

interface IssueQueue_if;
  // Dispatch interface
  logic push;
  IQ_entry_t push_entry;
  logic full;

  // Issue output
  logic issue_valid;
  IQ_entry_t issue_entry;

  modport Dispatcher_Side(input full, output push, output push_entry);

  modport IQ_Side(
      input push,
      input push_entry,
      output full,
      output issue_valid,
      output issue_entry
  );

  modport Execution_Side(input issue_valid, input issue_entry);

endinterface : IssueQueue_if


interface Commit_if;
  ROB_entry_t committed_rob_entries[COMMIT_WIDTH-1:0];

  modport ROB_Side(output committed_rob_entries);

  modport Renamer_Side(input committed_rob_entries);

  modport STQ_Side(input committed_rob_entries);

endinterface : Commit_if

interface ReorderBuffer_if;
  // Dispatch interface
  logic push;
  ROB_entry_t push_entry;

  logic full;

  logic [ROB_IDX_WIDTH-1:0] head_ptr;
  logic [ROB_IDX_WIDTH-1:0] tail_ptr;
  logic [ROB_IDX_WIDTH-1:0] next_tail_ptr;

  ROB_entry_t head_entry;

  // We allow `COMMIT_WIDTH` instructions to be committed at once, 
  // so we need to track which ones are executed and ready to commit
  executed_op_t ALU_executed_op;

  executed_op_t STR_executed_op;

  modport Dispatcher_Side(input full, tail_ptr, output push, output push_entry);

  modport ROB_Side(
      input push,
      input push_entry,
      input ALU_executed_op, STR_executed_op,
      output full,
      output head_entry,
      output head_ptr,
      output tail_ptr,
      output next_tail_ptr
  );

  modport Renamer_Side(input tail_ptr, input next_tail_ptr);

  modport Execution_Side(output ALU_executed_op, STR_executed_op);

  modport Commit_Side(input head_entry, input head_ptr, input tail_ptr);

endinterface : ReorderBuffer_if

/// TODO: Need to be expanded to account for the multiple ports of the RF
/// The size will be COMMIT_WIDTH
interface Writeback_if;

  writeback_t alu_writeback;
  writeback_t mem_writeback;

  modport Renamer_Side(input alu_writeback, input mem_writeback);

  modport IQ_Side(input alu_writeback, input mem_writeback);

  modport RegisterFile_Side(output alu_writeback, output mem_writeback);
endinterface : Writeback_if

interface ALU_if;
  word_t   op_a;
  word_t   op_b;
  alu_op_t opcode;
  word_t   out;

  modport ALU_side(input op_a, input op_b, input opcode, output out);
endinterface : ALU_if

interface RF_Read_if;
  logic en;
  physical_reg_t addr;
  word_t data;
  addr_t PC;

  modport RF_side(input en, input addr, output data);

  modport User_side(output en, output addr, input data);

endinterface : RF_Read_if

interface RF_Write_if;
  logic en;
  physical_reg_t addr;
  word_t data;
  logic [ROB_IDX_WIDTH-1:0] rob_idx;
  addr_t PC;

  modport RF_side(input en, input addr, input rob_idx, input PC, input data);

  modport User_side(output data, output en, output addr, output rob_idx, output PC);

endinterface : RF_Write_if

interface AGU_if;

  logic [31:0] base;
  logic [31:0] offset;

  /// 0=byte, 1=half, 2=word
  logic [1:0] size;

  logic [31:0] addr;
  logic misalign;

  modport AGU_side(input base, input offset, input size, output addr, output misalign);
endinterface

interface Memory_Bus_if;
  addr_t addr;
  word_t wdata;
  word_t rdata;
  logic  read_en;
  logic  write_en;

  /// Bus master/router master: this connects to the Peripherals, and passes
  /// the CPU signals along to them, as well as gathering rdata from the Peripherals
  modport Master_side(output addr, wdata, read_en, write_en, input rdata);

  /// Peripherals (PPU/APU/etc.) are slaves: they listen to addr, write_en/read_en,
  /// and drive rdata when selected.
  modport Slave_side(input addr, wdata, read_en, write_en, output rdata);

endinterface
