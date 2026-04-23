import riscv_types_pkg::*;
import riscv_lsu_types_pkg::*;
import riscv_constants_pkg::*;

interface STQ_if;
  parameter int DEPTH = STQ_WIDTH;
  localparam int IDX_W = $clog2(DEPTH);

  /// Decode allocation
  logic push;

  /// We pop the top of STQ as soon as we sucessfully send it to memory
  logic pop;

  logic full;
  logic empty;

  stq_entry_t entries[DEPTH];
  logic [DEPTH-1:0] valid_mask;

  /// Tail pointer for the next available slot in the STQ
  /// Recorded by the decoder and used to track the STQ entry in the memory IQ.
  logic [IDX_W-1:0] tail_idx;

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

  // ----------------------------
  // Commit from ROB
  // ----------------------------

  // ROB commit says this store is now architecturally committed
  logic commit;

  /// Index of the store in the STQ being committed (from the ROB)
  logic [IDX_W-1:0] commit_idx;

  modport Decoder_side(input tail_idx, output push);

  modport STQ_side(
      input push, pop,
      input write_addr, write_addr_idx, write_addr_value,
      input write_data, write_data_idx, write_data_value,
      input commit, commit_idx,
      output full, empty,
      output entries,
      output valid_mask,
      output tail_idx,
      output mem_store_valid, mem_store_addr, mem_store_data
  );

  modport LSU_side(input mem_store_valid, mem_store_addr, mem_store_data, output pop);

  modport ROB_side(output commit, commit_idx);

  modport Execution_side(
      output write_addr,
      output write_addr_idx,
      output write_addr_value,

      output write_data,
      output write_data_idx,
      output write_data_value
  );
endinterface : STQ_if
