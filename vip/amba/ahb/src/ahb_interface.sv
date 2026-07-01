// vip/amba/ahb/src/ahb_interface.sv
`ifndef AHB_INTERFACE_SV
`define AHB_INTERFACE_SV

interface ahb_interface #(
    parameter ADDR_WIDTH = `AHB_ADDR_WIDTH,
    parameter DATA_WIDTH = `AHB_DATA_WIDTH
) (
    input logic HCLK,
    input logic HRESETn
);
    // Signal declarations
    logic [ADDR_WIDTH-1:0] HADDR;
    logic [1:0]            HTRANS;
    logic                  HWRITE;
    logic [2:0]            HSIZE;
    logic [2:0]            HBURST;
    logic [3:0]            HPROT;
    logic [DATA_WIDTH-1:0] HWDATA;
    logic [DATA_WIDTH-1:0] HRDATA;
    logic                  HREADY;
    logic [1:0]            HRESP;
    logic                  HSEL;
    logic                  HMASTLOCK;
    logic                  HBUSREQ;  // Full AHB
    logic                  HGRANT;   // Full AHB

    // Master clocking block
    clocking master_cb @(posedge HCLK);
        default input #1 output #1;
        output HADDR;
        output HTRANS;
        output HWRITE;
        output HSIZE;
        output HBURST;
        output HPROT;
        output HWDATA;
        output HMASTLOCK;
        output HBUSREQ;
        input  HRDATA;
        input  HREADY;
        input  HRESP;
        input  HGRANT;
    endclocking

    // Slave clocking block
    clocking slave_cb @(posedge HCLK);
        default input #1 output #1;
        input  HADDR;
        input  HTRANS;
        input  HWRITE;
        input  HSIZE;
        input  HBURST;
        input  HPROT;
        input  HWDATA;
        input  HSEL;
        input  HMASTLOCK;
        output HRDATA;
        output HREADY;
        output HRESP;
    endclocking

    // Monitor clocking block
    clocking monitor_cb @(posedge HCLK);
        default input #1 output #1;
        input HADDR;
        input HTRANS;
        input HWRITE;
        input HSIZE;
        input HBURST;
        input HPROT;
        input HWDATA;
        input HRDATA;
        input HREADY;
        input HRESP;
        input HSEL;
        input HMASTLOCK;
        input HBUSREQ;
        input HGRANT;
    endclocking

    // No modports — use clocking blocks only (coding standard)

    // Reset cleanup tasks for driver/monitor
    task reset_master_signals();
        HADDR     <= '0;
        HTRANS    <= 2'b00;  // IDLE
        HWRITE    <= '0;
        HSIZE     <= '0;
        HBURST    <= '0;
        HPROT     <= '0;
        HWDATA    <= '0;
        HMASTLOCK <= '0;
    endtask

    task reset_slave_signals();
        HRDATA <= '0;
        HREADY <= 1'b1;
        HRESP  <= 2'b00;  // OKAY
    endtask

endinterface

`endif // AHB_INTERFACE_SV
