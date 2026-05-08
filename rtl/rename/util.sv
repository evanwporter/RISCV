import riscv_constants_pkg::*;
import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_decoder_types_pkg::*;
import riscv_renamer_types_pkg::*;
import riscv_rob_types_pkg::*;

package riscv_renamer_util_pkg;

  import riscv_renamer_types_pkg::*;
  import riscv_regs_types_pkg::*;

  /// Get the next free physical register from the free list. This is used for renaming
  /// destination registers of new instructions.
  /// Could be replaced with always_comb
  function automatic next_free_t get_next_free(free_list_t fl);
    next_free_t result;

    result.valid = 0;
    result.idx   = P0;

    for (int i = 1; i < NUM_PHYSICAL_REGS; i++) begin
      if (fl[i] && !result.valid) begin
        result.valid = 1;
        result.idx   = physical_reg_t'(i);
      end
    end

    return result;
  endfunction

endpackage : riscv_renamer_util_pkg
