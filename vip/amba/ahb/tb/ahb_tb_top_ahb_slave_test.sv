// vip/amba/ahb/tb/ahb_tb_top_slave.sv
// Testbench top for slave agent test (no DUT - slave agent drives responses)
`ifndef AHB_TB_TOP_SLAVE_SV
`define AHB_TB_TOP_SLAVE_SV

module ahb_tb_top_slave;
    import uvm_pkg::*;
    import hx_ahb_pkg::*;
    import hx_ahb_tb_pkg::*;
    `include "uvm_macros.svh"

    // Clock and reset
    logic HCLK;
    logic HRESETn;

    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK;
    end

    initial begin
        HRESETn = 0;
        repeat (10) @(posedge HCLK);
        HRESETn = 1;
    end

    // Single interface shared by master and slave
    ahb_interface ahb_if (.HCLK(HCLK), .HRESETn(HRESETn));

    // Set vif for both agents
    initial begin
        uvm_config_db#(virtual ahb_interface)::set(null, "*.master_agt[0]", "vif", ahb_if);
        uvm_config_db#(virtual ahb_interface)::set(null, "*.slave_agt[0]",  "vif", ahb_if);
    end

    // Run test
    initial begin
        run_test();
    end
endmodule

`endif // AHB_TB_TOP_SLAVE_SV
