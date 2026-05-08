import riscv_types_pkg::*;
import riscv_lsu_types_pkg::*;

module AGU (
    AGU_if.AGU_side bus
);

  word_t addr_sum;

  always_comb begin
    addr_sum = bus.base + bus.offset;
    bus.addr = '0;
    bus.misalign = 1'b0;

    bus.addr = addr_sum;

    case (bus.size)
      BYTE: bus.misalign = 1'b0;
      HALFWORD: bus.misalign = addr_sum[0];
      WORD: bus.misalign = |addr_sum[1:0];
      default: bus.misalign = 1'b0;
    endcase
  end
endmodule
