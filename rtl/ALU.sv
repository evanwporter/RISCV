import riscv_types_pkg::*;
import riscv_decoder_types_pkg::*;

module ALU (
    ALU_if.ALU_side bus
);

  always_comb begin
    bus.out = '0;
    unique case (bus.opcode)
      OP_ADD:  bus.out = bus.op_a + bus.op_b;
      OP_SUB:  bus.out = bus.op_a - bus.op_b;
      OP_AND:  bus.out = bus.op_a & bus.op_b;
      OP_OR:   bus.out = bus.op_a | bus.op_b;
      OP_XOR:  bus.out = bus.op_a ^ bus.op_b;
      OP_SLL:  bus.out = bus.op_a << bus.op_b;
      OP_SRL:  bus.out = bus.op_a >> bus.op_b;
      OP_SRA:  bus.out = $signed(bus.op_a) >>> bus.op_b[4:0];
      OP_SLT:  bus.out = ($signed(bus.op_a) < $signed(bus.op_b)) ? 32'b1 : 32'b0;
      OP_SLTU: bus.out = (bus.op_a < bus.op_b) ? 32'b1 : 32'b0;
    endcase
  end

endmodule
