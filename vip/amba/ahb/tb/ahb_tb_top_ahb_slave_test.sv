// vip/amba/ahb/tb/ahb_tb_top_slave.sv
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

    // Interfaces
    ahb_interface mst_if (.HCLK(HCLK), .HRESETn(HRESETn));
    ahb_interface slv_if (.HCLK(HCLK), .HRESETn(HRESETn));

    // DUT
    ahb_slave_ram dut (
        .HCLK    (slv_if.HCLK),
        .HRESETn (slv_if.HRESETn),
        .HSEL    (1'b1),
        .HTRANS  (slv_if.HTRANS),
        .HWRITE  (slv_if.HWRITE),
        .HSIZE   (slv_if.HSIZE),
        .HBURST  (slv_if.HBURST),
        .HADDR   (slv_if.HADDR),
        .HWDATA  (slv_if.HWDATA),
        .HRDATA  (slv_if.HRDATA),
        .HREADY  (slv_if.HREADY),
        .HRESP   (slv_if.HRESP)
    );

    // Connect master driver output to slave interface
    assign slv_if.HTRANS  = mst_if.HTRANS;
    assign slv_if.HWRITE  = mst_if.HWRITE;
    assign slv_if.HSIZE   = mst_if.HSIZE;
    assign slv_if.HBURST  = mst_if.HBURST;
    assign slv_if.HADDR   = mst_if.HADDR;
    assign slv_if.HWDATA  = mst_if.HWDATA;
    assign mst_if.HRDATA  = slv_if.HRDATA;
    assign mst_if.HREADY  = slv_if.HREADY;
    assign mst_if.HRESP   = slv_if.HRESP;

    // Set vif
    initial begin
        uvm_config_db#(virtual ahb_interface)::set(null, "*.master_agt[0]", "vif", mst_if);
        uvm_config_db#(virtual ahb_interface)::set(null, "*.slave_agt[0]", "vif", slv_if);
    end

    // Run test
    initial begin
        run_test();
    end
endmodule

`endif // AHB_TB_TOP_SLAVE_SV
