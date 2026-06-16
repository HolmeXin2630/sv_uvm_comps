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
        default input #1 output #1;
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

    // Modports
    modport master  (clocking master_cb,  input PRESETn);
    modport slave   (clocking slave_cb,   input PRESETn);
    modport monitor (clocking monitor_cb, input PRESETn);

endinterface

`endif // APB_INTERFACE_SV
