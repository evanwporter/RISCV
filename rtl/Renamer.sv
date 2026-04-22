import riscv_constants_pkg::*;
import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_decoder_types_pkg::*;

module RegisterRenamer (
    input logic clk,
    input logic reset,
    input free_list_t freed_list,
    input decoder_output_t decoder_out,
    output rat_output_t rat_out,
    Writeback_if.Renamer_Side wb_bus
);

  physical_reg_t [31:0] RAT;

  free_list_t free_list;

  word_t busy_list;

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

  logical_reg_t rs1, rs2;

  always_comb begin
    if (!decoder_out.uop.has_rs1) rs1 = x0;
    else rs1 = decoder_out.uop.rs1;
    if (!decoder_out.uop.has_rs2) rs2 = x0;
    else rs2 = decoder_out.uop.rs2;
  end

  always_ff @(posedge clk) begin
    next_free_t next_free;

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
      if (decoder_out.valid) begin
        rat_out.advance_pipeline <= 1'b1;

        free_list_next = free_list | freed_list;

        // Read sources
        rat_out.Ps1 <= RAT[rs1];
        rat_out.Ps2 <= RAT[rs2];

        rat_out.Ps1_ready <= ~busy_list[RAT[rs1]];
        rat_out.Ps2_ready <= ~busy_list[RAT[rs2]];

        // Allocate
        next_free = get_next_free(free_list_next);

        if (wb_bus.valid) begin
          busy_list[wb_bus.pdst] <= 1'b0;
        end

        if (decoder_out.uop.has_rd) begin
          if (decoder_out.uop.rd == x0) begin
            // x0 special case
            rat_out.Pd_old <= P0;
            rat_out.Pd_new <= P0;
          end else if (next_free.valid) begin
            rat_out.Pd_old <= RAT[decoder_out.uop.rd];
            rat_out.Pd_new <= next_free.idx;

            RAT[decoder_out.uop.rd] <= next_free.idx;
            free_list_next[next_free.idx] = 1'b0;

            busy_list[next_free.idx] <= 1'b1;
          end else begin
            // no free register
            rat_out.Pd_old <= RAT[decoder_out.uop.rd];
            rat_out.Pd_new <= RAT[decoder_out.uop.rd];
          end
        end else begin
          // no destination instruction
          rat_out.Pd_old <= P0;
          rat_out.Pd_new <= P0;
        end

        rat_out.uop <= decoder_out.uop;

        rat_out.stq_idx <= decoder_out.stq_idx;

        free_list <= free_list_next;
      end
    end
  end


endmodule : RegisterRenamer
