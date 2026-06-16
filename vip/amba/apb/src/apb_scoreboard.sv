`ifndef APB_SCOREBOARD_SV
`define APB_SCOREBOARD_SV

class apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(apb_scoreboard)

    uvm_analysis_imp #(apb_transaction, apb_scoreboard) ap;

    // Expected memory model
    bit [`APB_DATA_WIDTH-1:0] expected_mem [bit [`APB_ADDR_WIDTH-1:0]];

    int unsigned match_count = 0;
    int unsigned mismatch_count = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void write(apb_transaction t);
        if (t.write) begin
            expected_mem[t.addr] = t.data;
        end else begin
            if (expected_mem.exists(t.addr)) begin
                if (t.data !== expected_mem[t.addr]) begin
                    `uvm_error("SCB", $sformatf("Read mismatch at 0x%08h: expected=0x%08h, actual=0x%08h",
                        t.addr, expected_mem[t.addr], t.data))
                    mismatch_count++;
                end else begin
                    match_count++;
                end
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCB", $sformatf("Matches=%0d, Mismatches=%0d", match_count, mismatch_count), UVM_LOW)
    endfunction
endclass

`endif // APB_SCOREBOARD_SV
