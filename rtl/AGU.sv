import riscv_types_pkg::*;
import riscv_decoder_types_pkg::*;

module AGU (
    AGU_if.AGU_side bus
);

  word_t addr_sum;

  always_comb begin
    addr_sum    = bus.base + bus.offset;
    bus.addr    = '0;
    bus.misalign = 1'b0;

    bus.addr = addr_sum;

    case (bus.size)
      2'd0: bus.misalign = 1'b0;  // byte
      2'd1: bus.misalign = addr_sum[0];  // halfword
      2'd2: bus.misalign = |addr_sum[1:0];  // word
      default: bus.misalign = 1'b0;
    endcase
  end
endmodule
