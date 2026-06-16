`ifndef APB_COVERAGE_SV
`define APB_COVERAGE_SV

class apb_coverage extends uvm_subscriber #(apb_transaction);
    `uvm_component_utils(apb_coverage)

    apb_transaction txn;

    covergroup cg_apb;
        cp_write: coverpoint txn.write {
            bins read  = {0};
            bins write = {1};
        }
        cp_slverr: coverpoint txn.slverr {
            bins no_err = {0};
            bins err    = {1};
        }
        cp_idle: coverpoint txn.idle_cycles {
            bins zero = {0};
            bins low  = {[1:2]};
            bins high = {[3:5]};
        }
        cx_write_err: cross cp_write, cp_slverr;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_apb = new();
    endfunction

    function void write(apb_transaction t);
        txn = t;
        cg_apb.sample();
    endfunction
endclass

`endif // APB_COVERAGE_SV
