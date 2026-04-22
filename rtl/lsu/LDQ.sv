import riscv_types_pkg::*;
import riscv_lsu_types_pkg::*;

module LDQ #(
    parameter  int DEPTH = 32,
    localparam int IDX_W = $clog2(DEPTH)
) (
    input logic clk,
    input logic rst_n,

    // Decode allocation
    input  logic             alloc_i,
    input  logic [     31:0] alloc_st_dep_mask_i,
    output logic             alloc_ready_o,
    output logic [IDX_W-1:0] alloc_idx_o,

    // Load address arrives from execute / AGU
    input logic             issue_addr_i,
    input logic [IDX_W-1:0] issue_idx_i,
    input logic [      4:0] issue_addr_value_i,

    // Memory request channel for loads
    output logic             mem_load_valid_o,
    input  logic             mem_load_ready_i,
    output logic [      4:0] mem_load_addr_o,
    output logic [IDX_W-1:0] mem_load_idx_o,

    // Memory response tagged by LDQ index
    input  logic              mem_resp_valid_i,
    input  logic  [IDX_W-1:0] mem_resp_idx_i,
    input  word_t             mem_resp_data_i,
    output logic              load_wb_valid_o,
    output logic  [IDX_W-1:0] load_wb_idx_o,
    output word_t             load_wb_data_o,

    // From STQ
    input stq_entry_t stq_entries_i[DEPTH],

    // Clear dependency bit when a store leaves the STQ
    input logic             clr_dep_i,
    input logic [IDX_W-1:0] clr_dep_idx_i,

    // Ordering failure detection: check this store against executed loads
    input  logic             commit_check_i,
    input  logic [IDX_W-1:0] commit_check_stq_idx_i,
    input  logic             commit_check_addr_valid_i,
    input  logic [      4:0] commit_check_addr_i,
    output logic             order_fail_o,

    // Snapshot/debug
    output ldq_entry_t entries_o[DEPTH]
);

  ldq_entry_t entries_q[DEPTH];
  logic [IDX_W-1:0] head_q, tail_q;
  logic [IDX_W:0] count_q;

  assign alloc_ready_o = (count_q != DEPTH);
  assign alloc_idx_o   = tail_q;

  genvar gi;
  generate
    for (gi = 0; gi < DEPTH; gi++) begin : g_ldq_out
      assign entries_o[gi] = entries_q[gi];
    end
  endgenerate

  // ------------------------------------------------------------
  // Match helper for a given load
  // ------------------------------------------------------------
  function automatic logic find_forward_match(
      input logic [4:0] addr, input logic [31:0] mask, output logic [IDX_W-1:0] fwd_idx,
      output word_t fwd_data, output logic any_match, output logic blocked_by_missing_data);
    logic found_valid;
    logic found_any;
    logic found_missing;
    logic [IDX_W-1:0] best_idx;
    word_t best_data;

    integer j;
    begin
      found_valid   = 1'b0;
      found_any     = 1'b0;
      found_missing = 1'b0;
      best_idx      = '0;
      best_data     = '0;

      // Youngest matching older store wins.
      // Since mask encodes older stores only, we just search all set bits.
      for (j = 0; j < DEPTH; j++) begin
        if (mask[j] &&
            stq_entries_i[j].valid &&
            stq_entries_i[j].addr_valid &&
            (stq_entries_i[j].addr == addr)) begin
          found_any = 1'b1;
          if (stq_entries_i[j].data_valid) begin
            found_valid = 1'b1;
            best_idx = j[IDX_W-1:0];
            best_data = stq_entries_i[j].data;
          end else begin
            found_missing = 1'b1;
          end
        end
      end

      fwd_idx = best_idx;
      fwd_data = best_data;
      any_match = found_any;
      blocked_by_missing_data = found_missing && !found_valid;
      return found_valid;
    end
  endfunction

  // ------------------------------------------------------------
  // Request selection:
  //   priority 1: newly issued load address
  //   priority 2: oldest sleeping load retry
  // ------------------------------------------------------------
  logic               retry_found;
  logic   [IDX_W-1:0] retry_idx;
  logic   [      4:0] retry_addr;

  integer             m;
  always_comb begin
    retry_found = 1'b0;
    retry_idx   = '0;
    retry_addr  = '0;

    for (m = 0; m < DEPTH; m++) begin
      if (!retry_found &&
          entries_q[m].valid &&
          entries_q[m].sleeping &&
          entries_q[m].addr_valid) begin
        retry_found = 1'b1;
        retry_idx   = m[IDX_W-1:0];
        retry_addr  = entries_q[m].addr;
      end
    end
  end

  logic             resolve_valid;
  logic [IDX_W-1:0] resolve_idx;
  logic [      4:0] resolve_addr;
  logic [     31:0] resolve_mask;

  always_comb begin
    if (issue_addr_i) begin
      resolve_valid = 1'b1;
      resolve_idx   = issue_idx_i;
      resolve_addr  = issue_addr_value_i;
      resolve_mask  = entries_q[issue_idx_i].st_dep_mask;
    end else if (retry_found) begin
      resolve_valid = 1'b1;
      resolve_idx   = retry_idx;
      resolve_addr  = retry_addr;
      resolve_mask  = entries_q[retry_idx].st_dep_mask;
    end else begin
      resolve_valid = 1'b0;
      resolve_idx   = '0;
      resolve_addr  = '0;
      resolve_mask  = '0;
    end
  end

  logic              do_forward;
  logic  [IDX_W-1:0] fwd_idx_unused;
  word_t             fwd_data;
  logic              any_match;
  logic              blocked_by_missing_data;

  always_comb begin
    if (resolve_valid) begin
      do_forward = find_forward_match(resolve_addr, resolve_mask, fwd_idx_unused, fwd_data,
                                      any_match, blocked_by_missing_data);
    end else begin
      do_forward = 1'b0;
      fwd_idx_unused = '0;
      fwd_data = '0;
      any_match = 1'b0;
      blocked_by_missing_data = 1'b0;
    end
  end

  // Load request goes to memory iff:
  //  - there is a load to resolve
  //  - no forwarding match
  //  - not blocked by older store with missing data
  assign mem_load_valid_o = resolve_valid && !do_forward && !blocked_by_missing_data;
  assign mem_load_addr_o = resolve_addr;
  assign mem_load_idx_o = resolve_idx;

  assign load_wb_valid_o = mem_resp_valid_i || (resolve_valid && do_forward);
  assign load_wb_idx_o = mem_resp_valid_i ? mem_resp_idx_i : resolve_idx;
  assign load_wb_data_o = mem_resp_valid_i ? mem_resp_data_i : fwd_data;

  // Ordering failure:
  // If a store commits and there exists a load that:
  //   - depended on that store
  //   - already executed
  //   - has same address
  // then we flag failure.
  integer t;
  always_comb begin
    order_fail_o = 1'b0;
    if (commit_check_i && commit_check_addr_valid_i) begin
      for (t = 0; t < DEPTH; t++) begin
        if (entries_q[t].valid &&
            entries_q[t].executed &&
            entries_q[t].addr_valid &&
            entries_q[t].st_dep_mask[commit_check_stq_idx_i] &&
            (entries_q[t].addr == commit_check_addr_i) &&
            (entries_q[t].from_mem || entries_q[t].from_forward)) begin
          order_fail_o = 1'b1;
        end
      end
    end
  end

  integer k;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      head_q  <= '0;
      tail_q  <= '0;
      count_q <= '0;
      for (k = 0; k < DEPTH; k++) begin
        entries_q[k] <= '0;
      end
    end else begin
      // Allocate
      if (alloc_i && alloc_ready_o) begin
        entries_q[tail_q]             <= '0;
        entries_q[tail_q].valid       <= 1'b1;
        entries_q[tail_q].st_dep_mask <= alloc_st_dep_mask_i;
        tail_q                        <= tail_q + 1'b1;
        count_q                       <= count_q + 1'b1;
      end

      // Clear dep bit when a store leaves STQ
      if (clr_dep_i) begin
        for (k = 0; k < DEPTH; k++) begin
          entries_q[k].st_dep_mask[clr_dep_idx_i] <= 1'b0;
        end
      end

      // Address arrives for a load
      if (issue_addr_i) begin
        entries_q[issue_idx_i].addr_valid <= 1'b1;
        entries_q[issue_idx_i].addr       <= issue_addr_value_i;
      end

      // Resolve a newly-issued or sleeping load
      if (resolve_valid) begin
        if (do_forward) begin
          entries_q[resolve_idx].executed     <= 1'b1;
          entries_q[resolve_idx].sleeping     <= 1'b0;
          entries_q[resolve_idx].succeeded    <= 1'b1;
          entries_q[resolve_idx].from_forward <= 1'b1;
          entries_q[resolve_idx].from_mem     <= 1'b0;
        end else if (blocked_by_missing_data) begin
          entries_q[resolve_idx].sleeping <= 1'b1;
        end else if (mem_load_valid_o && mem_load_ready_i) begin
          entries_q[resolve_idx].executed     <= 1'b1;
          entries_q[resolve_idx].sleeping     <= 1'b0;
          entries_q[resolve_idx].from_forward <= 1'b0;
          // from_mem gets set on response
        end
      end

      // Memory response completes load
      if (mem_resp_valid_i) begin
        entries_q[mem_resp_idx_i].succeeded <= 1'b1;
        entries_q[mem_resp_idx_i].from_mem  <= 1'b1;
      end

      // Simple retirement/freeing policy:
      // once succeeded, free the oldest succeeded entry.
      if (entries_q[head_q].valid && entries_q[head_q].succeeded) begin
        entries_q[head_q] <= '0;
        head_q <= head_q + 1'b1;
        count_q <= count_q - 1'b1;
      end
    end
  end

endmodule : LDQ
