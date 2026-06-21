`ifndef APB_COVERAGE_SV
`define APB_COVERAGE_SV

class apb_coverage extends uvm_subscriber #(apb_transaction);
    `uvm_component_utils(apb_coverage)

    apb_transaction txn;

    covergroup cg_apb;
        option.per_instance = 1;

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

        cp_addr_range: coverpoint txn.addr[31:12] {
            bins low  = {[0:32'h000F_FFFF]};
            bins mid  = {[32'h0010_0000:32'h00FF_FFFF]};
            bins high = {[32'h0100_0000:32'hFFFF_FFFF]};
        }

        cp_data_pattern: coverpoint txn.data[31:0] {
            bins zero     = {32'h0000_0000};
            bins ones     = {32'hFFFF_FFFF};
            bins walking  = {32'h0000_0001, 32'h0000_0002, 32'h0000_0004, 32'h0000_0008,
                            32'h0000_0010, 32'h0000_0020, 32'h0000_0040, 32'h0000_0080,
                            32'h0000_0100, 32'h0000_0200, 32'h0000_0400, 32'h0000_0800,
                            32'h0000_1000, 32'h0000_2000, 32'h0000_4000, 32'h0000_8000,
                            32'h0001_0000, 32'h0002_0000, 32'h0004_0000, 32'h0008_0000,
                            32'h0010_0000, 32'h0020_0000, 32'h0040_0000, 32'h0080_0000,
                            32'h0100_0000, 32'h0200_0000, 32'h0400_0000, 32'h0800_0000,
                            32'h1000_0000, 32'h2000_0000, 32'h4000_0000, 32'h8000_0000};
            bins others   = default;
        }

        cx_write_err: cross cp_write, cp_slverr;
        cx_write_addr: cross cp_write, cp_addr_range;
        cx_write_data: cross cp_write, cp_data_pattern;
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
