import riscv_types_pkg::*;
import riscv_lsu_types_pkg::*;
import riscv_constants_pkg::*;
import riscv_regs_types_pkg::*;

interface STQ_if;
  parameter int DEPTH = STQ_WIDTH;
  localparam int IDX_W = $clog2(DEPTH);

  /// Decode allocation
  logic push;

  /// We pop the top of STQ as soon as we sucessfully send it to memory
  logic pop;

  /// ALlocate a new store in the STQ and record its ROB index
  logic [ROB_IDX_WIDTH-1:0] push_rob_idx;

  logic full;
  logic empty;

  stq_entry_t entries[DEPTH];
  logic [DEPTH-1:0] valid_mask;

  /// Tail pointer for the next available slot in the STQ
  /// Recorded by the decoder and used to track the STQ entry in the memory IQ.
  logic [IDX_W-1:0] tail_idx;

  /// Head pointer for the next entry to be popped from the STQ
  /// Head represents the oldest store in the queue, and only it may fire (pop from queue and send to memory)
  logic [IDX_W-1:0] head_idx;

  // -------------------------
  // Record Store Address
  // -------------------------

  /// Store address write (`uopSTA` or combined store)
  logic write_addr;

  /// Index of the store in the STQ being written (from the IQ entry)
  logic [IDX_W-1:0] write_addr_idx;

  /// Calculated value of address from AGU for this store
  addr_t write_addr_value;

  // -------------------------
  // Record Store Data
  // -------------------------

  // Store data write (uopSTD or combined store)
  logic write_data;

  /// Index of the store in the STQ being written (from the IQ entry)
  logic [IDX_W-1:0] write_data_idx;

  /// Register value of the store data
  word_t write_data_value;

  // ----------------------------
  // Memory Output (head of STQ)
  // ----------------------------

  /// The head of the STQ is ready to fire (send to memory)
  logic mem_store_valid;

  /// Address to send to memory for the head store
  addr_t mem_store_addr;

  /// Data to send to memory for the head store
  word_t mem_store_data;

  modport Decoder_side(input tail_idx, output push, output push_rob_idx);

  modport STQ_side(
      input push, pop,
      input push_rob_idx,
      input write_addr, write_addr_idx, write_addr_value,
      input write_data, write_data_idx, write_data_value,
      output full, empty,
      output entries,
      output valid_mask,
      output tail_idx, head_idx,
      output mem_store_valid, mem_store_addr, mem_store_data
  );

  modport LSU_side(input mem_store_valid, mem_store_addr, mem_store_data, output pop);

  modport LDQ_side(input entries, input pop, head_idx);

  modport Execution_side(
      output write_addr,
      output write_addr_idx,
      output write_addr_value,

      output write_data,
      output write_data_idx,
      output write_data_value
  );
endinterface : STQ_if

interface LDQ_if;

  /// Decode allocation
  logic push;

  logic full;

  /// Pointer to the first available slot in the LDQ
  /// Recorded by the decoder and used to track the LDQ entry in the memory IQ.
  logic [LDQ_IDX_WIDTH-1:0] free_idx;

  // -------------------------
  // Record Load Address
  // -------------------------

  logic write_addr;
  logic [LDQ_IDX_WIDTH-1:0] write_addr_idx;
  addr_t write_addr_value;

  // ----------------------------
  // Memory Output
  // ----------------------------

  /// An entry in the lDQ is ready to fire (send to memory)
  logic mem_load_valid;

  /// Address to send to memory for the load/read
  addr_t mem_load_addr;

  physical_reg_t mem_load_pdst;

  logic [ROB_IDX_WIDTH-1:0] mem_load_rob_idx;

  addr_t mem_load_PC;

  modport Decoder_side(input free_idx, output push);

  modport LSU_side(
      input mem_load_valid, mem_load_addr, mem_load_pdst, mem_load_rob_idx, mem_load_PC
  );

  modport LDQ_side(
      input push,
      input write_addr, write_addr_idx, write_addr_value,
      output full,
      output mem_load_valid, mem_load_addr, mem_load_pdst, mem_load_rob_idx, mem_load_PC,
      output free_idx
  );

  modport Execution_side(output write_addr, output write_addr_idx, output write_addr_value);

endinterface : LDQ_if
