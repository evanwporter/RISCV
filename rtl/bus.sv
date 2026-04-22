import riscv_regs_types_pkg::*;
import riscv_rob_types_pkg::*;
import riscv_iq_types_pkg::*;
import riscv_types_pkg::*;
import riscv_decoder_types_pkg::*;

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

interface ReorderBuffer_if;
  // Dispatch interface
  logic push;
  ROB_entry_t push_entry;

  logic full;

  logic [4:0] head_ptr;
  logic [4:0] tail_ptr;
  logic [4:0] next_tail_ptr;

  ROB_entry_t head_entry;

  modport Dispatcher_Side(input full, tail_ptr, next_tail_ptr, output push, output push_entry);

  modport ROB_Side(
      input push,
      input push_entry,
      output full,
      output head_entry,
      output head_ptr,
      output tail_ptr,
      output next_tail_ptr
  );

  modport Commit_Side(input head_entry, input head_ptr, input tail_ptr);
endinterface : ReorderBuffer_if

interface Writeback_if;
  logic valid;

  /// Physical Register Destination (for writeback)
  /// Register getting written back to.
  physical_reg_t pdst;

  logic [4:0] rob_idx;

  modport Renamer_Side(input valid, input pdst);

  modport ROB_Side(input valid, input pdst, input rob_idx);

  modport IQ_Side(input valid, input pdst);

  modport RegisterFile_Side(output valid, output pdst, output rob_idx);
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

  modport RF_side(input en, input addr, output data);

  modport User_side(output en, output addr, input data);

endinterface : RF_Read_if

interface RF_Write_if;
  logic en;
  physical_reg_t addr;
  word_t data;
  logic [4:0] rob_idx;

  modport RF_side(input en, input addr, input rob_idx, input data);

  modport User_side(output data, output en, output addr, output rob_idx);

endinterface : RF_Write_if
