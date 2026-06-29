// vip/amba/ahb/src/ahb_agent_coverage.sv
`ifndef AHB_AGENT_COVERAGE_SV
`define AHB_AGENT_COVERAGE_SV

class ahb_agent_coverage extends uvm_subscriber #(ahb_transaction);
    `uvm_component_utils(ahb_agent_coverage)

    ahb_transaction txn;

    covergroup cg_beat;
        cp_htrans: coverpoint txn.is_first_beat {
            bins seq    = {0};
            bins nonseq = {1};
        }
        cp_xact_type: coverpoint txn.xact_type {
            bins read  = {READ};
            bins write = {WRITE};
        }
        cp_wait_cycles: coverpoint txn.wait_cycles {
            bins zero = {0};
            bins low  = {[1:3]};
            bins high = {[4:7]};
        }
        cx_htrans_xact: cross cp_htrans, cp_xact_type;
    endgroup

    covergroup cg_burst;
        cp_burst_type: coverpoint txn.burst_type {
            bins single = {SINGLE};
            bins incr   = {INCR};
            bins incr4  = {INCR4};
            bins incr8  = {INCR8};
            bins incr16 = {INCR16};
            bins wrap4  = {WRAP4};
            bins wrap8  = {WRAP8};
            bins wrap16 = {WRAP16};
        }
        cp_burst_size: coverpoint txn.burst_size {
            bins byte_8   = {BYTE};
            bins halfword = {HALFWORD};
            bins word     = {WORD};
        }
        cx_burst_type_size: cross cp_burst_type, cp_burst_size;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_beat  = new();
        cg_burst = new();
    endfunction

    function void write(ahb_transaction t);
        txn = t;
        cg_beat.sample();
        cg_burst.sample();
    endfunction
endclass

`endif // AHB_AGENT_COVERAGE_SV
