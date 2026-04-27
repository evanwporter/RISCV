import riscv_constants_pkg::*;
import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_decoder_types_pkg::*;
import riscv_renamer_types_pkg::*;

module RegisterRenamer (
    input logic clk,
    input logic reset,
    input decoder_output_t decoder_out,
    output rat_output_t rat_out,
    ReorderBuffer_if.Renamer_Side rob_bus,
    Writeback_if.Renamer_Side wb_bus,
    Commit_if.Renamer_Side commit_bus
);

  physical_reg_t [31:0] RAT;

  free_list_t free_list;

  // TODO Forward writeback results into busy list next
  logic [NUM_PHYSICAL_REGS-1:0] busy_list;
  logic [NUM_PHYSICAL_REGS-1:0] busy_list_next;

  checkpoint_t checkpoints[ROB_WIDTH];

  free_list_t free_list_next;

  typedef struct packed {
    logic valid;
    physical_reg_t idx;
  } next_free_t;

  // could be replaced with always_comb
  function automatic next_free_t get_next_free(free_list_t fl);
    next_free_t result;

    result.valid = 0;
    result.idx   = P0;

    for (int i = 0; i < NUM_PHYSICAL_REGS; i++) begin
      if (fl[i] && !result.valid) begin
        result.valid = 1;
        result.idx   = physical_reg_t'(i);
      end
    end

    return result;
  endfunction

  function automatic free_list_t get_freed_list;
    free_list_t freed_list = '0;

    for (int i = 0; i < COMMIT_WIDTH; i++) begin
      if (commit_bus.committed_rob_entries[i].valid &&
        commit_bus.committed_rob_entries[i].old_dest != P0) begin

        freed_list[commit_bus.committed_rob_entries[i].old_dest] = 1'b1;
      end
    end

    return freed_list;
  endfunction

  logical_reg_t rs1, rs2;
  uop_t uop;
  assign uop = decoder_out.uop;

  always_comb begin
    if (!uop.has_rs1) rs1 = x0;
    else rs1 = uop.rs1;
    if (!uop.has_rs2) rs2 = x0;
    else rs2 = uop.rs2;
  end

  next_free_t next_free;
  assign next_free = get_next_free(free_list);

  always_ff @(posedge clk) begin

    assert (free_list_next[0] == 1'b0)
    else $error("Error: physical register P0 should never be allocated");

    if (reset) begin
      free_list <= {NUM_PHYSICAL_REGS{1'b1}};

      // Mark all ready
      busy_list <= '0;

      for (int i = 0; i < 32; i++) begin
        RAT[i] <= physical_reg_t'(i);
        free_list[i] <= 1'b0;
      end
    end else begin
      rat_out <= '0;
      busy_list_next = busy_list;
      if (decoder_out.valid) begin
        rat_out.advance_pipeline <= 1'b1;

        free_list_next = free_list | get_freed_list();

        // Read sources
        rat_out.Ps1 <= uop.has_rs1 ? RAT[rs1] : P0;
        rat_out.Ps2 <= uop.has_rs2 ? RAT[rs2] : P0;

        rat_out.Ps1_ready <= uop.has_rs1 ? ~busy_list[RAT[rs1]] : 1'b1;
        rat_out.Ps2_ready <= uop.has_rs2 ? ~busy_list[RAT[rs2]] : 1'b1;

        if (wb_bus.alu_writeback.valid) begin
          busy_list[wb_bus.alu_writeback.pdst] <= 1'b0;
        end

        if (wb_bus.mem_writeback.valid) begin
          busy_list[wb_bus.mem_writeback.pdst] <= 1'b0;
        end

        if (uop.has_rd) begin
          if (uop.rd == x0) begin
            // x0 special case
            rat_out.Pd_old <= P0;
            rat_out.Pd_new <= P0;
          end else if (next_free.valid) begin
            rat_out.Pd_old <= RAT[uop.rd];
            rat_out.Pd_new <= next_free.idx;

            assert (next_free.idx != RAT[uop.rd])
            else
              $error(
                  "Error: next free register is the same as the current mapping for destination register %0d",
                  uop.rd
              );

            RAT[uop.rd] <= next_free.idx;
            free_list_next[next_free.idx] = 1'b0;

            busy_list[next_free.idx] <= 1'b1;
          end else begin
            // no free register
            rat_out.Pd_old <= RAT[uop.rd];
            rat_out.Pd_new <= RAT[uop.rd];
          end
        end else begin
          // no destination instruction
          rat_out.Pd_old <= P0;
          rat_out.Pd_new <= P0;
        end

        rat_out.uop <= uop;

        rat_out.stq_idx <= decoder_out.stq_idx;
        rat_out.ldq_idx <= decoder_out.ldq_idx;

        free_list <= free_list_next;
      end
    end
  end

  logic [ROB_IDX_WIDTH-1:0] next_rob_idx;
  assign next_rob_idx = rat_out.advance_pipeline ? rob_bus.next_tail_ptr : rob_bus.tail_ptr;

  always_ff @(posedge clk) begin
    if (reset) begin
    end else begin
      if (decoder_out.valid) begin
        if (uop.is_branch) begin
          checkpoints[next_rob_idx].free_list <= free_list;
          checkpoints[next_rob_idx].valid <= 1'b1;
          checkpoints[next_rob_idx].RAT <= RAT;
        end
      end
    end
  end

endmodule : RegisterRenamer
