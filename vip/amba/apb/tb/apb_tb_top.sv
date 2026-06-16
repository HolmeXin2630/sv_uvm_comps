`ifndef APB_TB_TOP_SV
`define APB_TB_TOP_SV

module apb_tb_top;
    import uvm_pkg::*;
    import hx_apb_pkg::*;
    `include "uvm_macros.svh"

    // Clock and reset
    logic PCLK;
    logic PRESETn;

    initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK;
    end

    initial begin
        PRESETn = 0;
        repeat (10) @(posedge PCLK);
        PRESETn = 1;
    end

    // Interface
    apb_interface apb_if (.PCLK(PCLK), .PRESETn(PRESETn));

    // DUT
    apb_slave_ram #(
        .WAIT_CYCLES(0),
        .INJECT_ERROR(0)
    ) dut (
        .PCLK    (apb_if.PCLK),
        .PRESETn (apb_if.PRESETn),
        .PSEL    (apb_if.PSEL),
        .PENABLE (apb_if.PENABLE),
        .PWRITE  (apb_if.PWRITE),
        .PADDR   (apb_if.PADDR),
        .PWDATA  (apb_if.PWDATA),
        .PRDATA  (apb_if.PRDATA),
        .PREADY  (apb_if.PREADY),
        .PSLVERR (apb_if.PSLVERR)
    );

    // Set vif
    initial begin
        uvm_config_db#(virtual apb_interface)::set(null, "*.apb_agt", "vif", apb_if);
    end

    // Run test
    initial begin
        run_test();
    end
endmodule

`endif // APB_TB_TOP_SV
