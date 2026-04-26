import riscv_iq_types_pkg::*;
import riscv_constants_pkg::*;

module IssueQueue (
    input logic clk,
    input logic reset,

    IssueQueue_if.IQ_Side bus,
    Writeback_if.IQ_Side  wb_bus
);

  IQ_entry_t entries[IQ_WIDTH];

  IssueQueue_if issueQueue_if ();

  // Determine if IQ is full
  always_comb begin
    bus.full = 1'b1;
    for (int i = 0; i < IQ_WIDTH; i++) begin
      if (!entries[i].valid) bus.full = 1'b0;
    end
  end

  // Find first free slot (for push)
  logic [IQ_IDX_WIDTH-1:0] free_idx;
  logic found_free;

  always_comb begin
    found_free = 1'b0;
    free_idx   = '0;

    for (int i = 0; i < IQ_WIDTH; i++) begin
      if (!entries[i].valid && !found_free) begin
        free_idx   = IQ_IDX_WIDTH'(i);
        found_free = 1'b1;
      end
    end
  end

  // Sequential logic
  always_ff @(posedge clk) begin
    if (reset) begin
      for (int i = 0; i < IQ_WIDTH; i++) begin
        entries[i] <= '0;
      end
    end else begin

      bus.issue_valid <= 1'b0;
      bus.issue_entry <= '0;

      // Issue selection
      for (int i = 0; i < IQ_WIDTH; i++) begin
        if (entries[i].valid && entries[i].prs1_ready && entries[i].prs2_ready) begin
          bus.issue_entry  <= entries[i];
          bus.issue_valid  <= 1'b1;
          entries[i].valid <= 1'b0;
          break;
        end
      end

      // Wakeup (broadcast)
      if (wb_bus.alu_writeback.valid) begin
        // Find all regs waiting on this dst reg and mark them ready
        for (int i = 0; i < IQ_WIDTH; i++) begin
          if (entries[i].valid) begin
            if (entries[i].prs1 == wb_bus.alu_writeback.pdst) entries[i].prs1_ready <= 1'b1;
            if (entries[i].prs2 == wb_bus.alu_writeback.pdst) entries[i].prs2_ready <= 1'b1;
          end
        end
      end

      // Wakeup (broadcast)
      if (wb_bus.mem_writeback.valid) begin
        // Find all regs waiting on this dst reg and mark them ready
        for (int i = 0; i < IQ_WIDTH; i++) begin
          if (entries[i].valid) begin
            if (entries[i].prs1 == wb_bus.mem_writeback.pdst) entries[i].prs1_ready <= 1'b1;
            if (entries[i].prs2 == wb_bus.mem_writeback.pdst) entries[i].prs2_ready <= 1'b1;
          end
        end
      end

      // Push (dispatch)
      if (bus.push && found_free) begin
        entries[free_idx] <= bus.push_entry;
        // entries[free_idx].valid <= 1'b1;
      end
    end
  end

endmodule
