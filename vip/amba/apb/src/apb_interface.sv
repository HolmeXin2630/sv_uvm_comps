`ifndef APB_INTERFACE_SV
`define APB_INTERFACE_SV

interface apb_interface #(
    parameter ADDR_WIDTH = `APB_ADDR_WIDTH,
    parameter DATA_WIDTH = `APB_DATA_WIDTH
) (
    input logic PCLK,
    input logic PRESETn
);
    // Signal declarations
    logic                    PSEL;
    logic                    PENABLE;
    logic [ADDR_WIDTH-1:0]   PADDR;
    logic                    PWRITE;
    logic [DATA_WIDTH-1:0]   PWDATA;
    logic [DATA_WIDTH-1:0]   PRDATA;
    logic                    PREADY;
    logic                    PSLVERR;
    logic [DATA_WIDTH/8-1:0] PSTRB;
    logic [2:0]              PPROT;

    // Master clocking block
    clocking master_cb @(posedge PCLK);
        default input #1 output #0;
        output PSEL;
        output PENABLE;
        output PADDR;
        output PWRITE;
        output PWDATA;
        output PSTRB;
        output PPROT;
        input  PRDATA;
        input  PREADY;
        input  PSLVERR;
    endclocking

    // Slave clocking block
    clocking slave_cb @(posedge PCLK);
        default input #1 output #1;
        input  PSEL;
        input  PENABLE;
        input  PADDR;
        input  PWRITE;
        input  PWDATA;
        input  PSTRB;
        input  PPROT;
        output PRDATA;
        output PREADY;
        output PSLVERR;
    endclocking

    // Monitor clocking block
    clocking monitor_cb @(posedge PCLK);
        default input #1 output #1;
        input PSEL;
        input PENABLE;
        input PADDR;
        input PWRITE;
        input PWDATA;
        input PRDATA;
        input PREADY;
        input PSLVERR;
        input PSTRB;
        input PPROT;
    endclocking

    // Protocol assertions
    // Check stability during ACCESS phase (after PENABLE is asserted)
    property apb_stable_addr;
        @(posedge PCLK) PSEL && PENABLE |-> $stable(PADDR);
    endproperty

    property apb_stable_write;
        @(posedge PCLK) PSEL && PENABLE |-> $stable(PWRITE);
    endproperty

    property apb_stable_wdata;
        @(posedge PCLK) PSEL && PENABLE && PWRITE |-> $stable(PWDATA);
    endproperty

    // Check PENABLE assertion after SETUP phase
    property apb_penable_after_psel;
        @(posedge PCLK) $rose(PSEL) && !PENABLE |=> PENABLE;
    endproperty

    // Check PREADY assertion after PENABLE
    property apb_pready_after_penable;
        @(posedge PCLK) PSEL && $rose(PENABLE) |-> ##[0:$] PREADY;
    endproperty

    assert property (apb_stable_addr)
        else $error("APB_CHK: Address changed during access phase");

    assert property (apb_stable_write)
        else $error("APB_CHK: Write signal changed during access phase");

    assert property (apb_stable_wdata)
        else $error("APB_CHK: Write data changed during access phase");

    assert property (apb_penable_after_psel)
        else $error("APB_CHK: PENABLE not asserted after PSEL");

    assert property (apb_pready_after_penable)
        else $error("APB_CHK: PREADY not asserted after PENABLE");

endinterface

`endif // APB_INTERFACE_SV
