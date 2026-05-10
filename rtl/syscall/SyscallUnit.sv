import riscv_types_pkg::*;
import riscv_regs_types_pkg::*;
import syscall_pkg::*;
import riscv_constants_pkg::*;

module SyscallUnit (
    input logic clk,
    input logic reset,

    Syscall_if.Syscall_Side bus,

    Commit_if.Syscall_Side commit_bus,

    output logic  syscall_wb_valid,
    output word_t syscall_wb_value,

    output logic halt
);

  always_comb begin
    for (int i = 0; i < COMMIT_WIDTH; i++) begin
      if (commit_bus.committed_rob_entries[i].valid &&
            commit_bus.committed_rob_entries[i].is_ecall) begin

        int result;
        int dpi_halt;

        /// TODO: We need to get the params from the ARAT mappings
        result = rv_syscall(int'(bus.a7), int'(bus.a0), int'(bus.a1), int'(bus.a2),
                            int'(bus.ecall_pc), dpi_halt);

        halt = dpi_halt != 0;

        bus.syscall_req[i].valid = 1'b1;
        bus.syscall_req[i].result = word_t'(result);
      end
    end
  end

  always_ff @(posedge clk) begin
    // if (reset) begin
    //   syscall_wb_valid <= 1'b0;
    //   syscall_wb_value <= '0;
    //   halt             <= 1'b0;
    // end else begin

    // end
  end

endmodule
