import riscv_iq_types_pkg::*;
import riscv_constants_pkg::*;
import riscv_regs_types_pkg::*;
import riscv_util_pkg::*;

module IssueQueue (
    input logic clk,
    input logic reset,
    input flush_t flush_info,
    IssueQueue_if.IQ_Side bus,
    Writeback_if.IQ_Side wb_bus,
    ReorderBuffer_if.ROB_Side rob_bus
);

  IQ_entry_t entries[IQ_WIDTH];

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

    for (int unsigned i = 0; i < IQ_WIDTH; i++) begin
      if (!entries[i].valid && !found_free) begin
        free_idx   = IQ_IDX_WIDTH'(i);
        found_free = 1'b1;
      end
    end
  end

  // Sequential logic
  always_ff @(posedge clk) begin
    logic [IQ_IDX_WIDTH-1:0] selected;
    logic found;

    if (reset) begin
      for (int i = 0; i < IQ_WIDTH; i++) begin
        entries[i] <= '0;
      end
    end else if (flush_info.valid) begin
      for (int i = 0; i < IQ_WIDTH; i++) begin
        if (entries[i].valid) begin
          /// We invalidate all entries younger than the flush entry
          if (is_younger(entries[i].rob_idx, flush_info.rob_idx, rob_bus.head_ptr)) begin
            $display("Flushing IQ entry %d (rob_idx=%d), PC=%d", i, entries[i].rob_idx,
                     entries[i].uop.pc);
            $fflush();
            entries[i].valid <= 1'b0;
          end
        end
      end
    end else begin

      bus.issue_valid <= 1'b0;
      bus.issue_entry <= '0;

      // Issue selection
      // TODO: This is a bit complicated, but if we add multiple EUs then we don't need the oldest.
      found = 1'b0;

      // Find oldest ready entry
      for (int i = 0; i < IQ_WIDTH; i++) begin
        if (entries[i].valid && entries[i].prs1_ready && entries[i].prs2_ready) begin
          if (!found || is_older(
                  entries[i].rob_idx, entries[selected].rob_idx, rob_bus.head_ptr
              )) begin
            selected = i[IQ_IDX_WIDTH-1:0];
            found = 1'b1;
          end
        end
      end

      // ------------------------------------------------------------
      // Issue
      // ------------------------------------------------------------
      bus.issue_valid <= found;
      if (found) begin
        $display("Issuing IQ entry %d (rob_idx=%d), PC=%d", selected, entries[selected].rob_idx,
                 entries[selected].uop.pc);
        bus.issue_entry <= entries[selected];
        entries[selected].valid <= 1'b0;
      end

      // ------------------------------------------------------------
      // Wakeup (broadcast)
      // ------------------------------------------------------------

      // ALU Wakeup (broadcast)
      if (wb_bus.alu_writeback.valid) begin
        // Find all regs waiting on this dst reg and mark them ready
        for (int i = 0; i < IQ_WIDTH; i++) begin
          if (entries[i].valid) begin
            if (entries[i].prs1 == wb_bus.alu_writeback.pdst) entries[i].prs1_ready <= 1'b1;
            if (entries[i].prs2 == wb_bus.alu_writeback.pdst) entries[i].prs2_ready <= 1'b1;
          end
        end
      end

      // Memory Wakeup (broadcast)
      if (wb_bus.mem_writeback.valid) begin
        // Find all regs waiting on this dst reg and mark them ready
        for (int i = 0; i < IQ_WIDTH; i++) begin
          if (entries[i].valid) begin
            if (entries[i].prs1 == wb_bus.mem_writeback.pdst) entries[i].prs1_ready <= 1'b1;
            if (entries[i].prs2 == wb_bus.mem_writeback.pdst) entries[i].prs2_ready <= 1'b1;
          end
        end
      end

      // ------------------------------------------------------------
      // Push (dispatch)
      // ------------------------------------------------------------
      if (bus.push && found_free) begin
        entries[free_idx] <= bus.push_entry;

        if (wb_bus.alu_writeback.valid) begin
          if (bus.push_entry.prs1 == wb_bus.alu_writeback.pdst)
            entries[free_idx].prs1_ready <= 1'b1;
          if (bus.push_entry.prs2 == wb_bus.alu_writeback.pdst)
            entries[free_idx].prs2_ready <= 1'b1;
        end

        if (wb_bus.mem_writeback.valid) begin
          if (bus.push_entry.prs1 == wb_bus.mem_writeback.pdst)
            entries[free_idx].prs1_ready <= 1'b1;
          if (bus.push_entry.prs2 == wb_bus.mem_writeback.pdst)
            entries[free_idx].prs2_ready <= 1'b1;
        end
      end
    end
  end

endmodule
