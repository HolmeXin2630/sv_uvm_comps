// vip/amba/ahb/src/ahb_slave_ram.sv
`ifndef AHB_SLAVE_RAM_SV
`define AHB_SLAVE_RAM_SV

module ahb_slave_ram #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter WAIT_CYCLES = 0,
    parameter INJECT_ERROR = 0
) (
    input  logic                    HCLK,
    input  logic                    HRESETn,
    input  logic                    HSEL,
    input  logic [1:0]              HTRANS,
    input  logic                    HWRITE,
    input  logic [2:0]              HSIZE,
    input  logic [2:0]              HBURST,
    input  logic [ADDR_WIDTH-1:0]   HADDR,
    input  logic [DATA_WIDTH-1:0]   HWDATA,
    output logic [DATA_WIDTH-1:0]   HRDATA,
    output logic                    HREADY,
    output logic [1:0]              HRESP
);
    logic [DATA_WIDTH-1:0] mem [0:1023];

    // Valid transfer detection
    logic valid_transfer;
    assign valid_transfer = HSEL && (HTRANS inside {2'b10, 2'b11});

    // Combinational response - single driver for HREADY, HRESP, HRDATA
    always_comb begin
        if (valid_transfer) begin
            HREADY = 1'b1;
            HRESP  = 2'b00;  // OKAY
            if (!HWRITE)
                HRDATA = mem[HADDR[11:2]];
            else
                HRDATA = '0;
        end else begin
            HREADY = 1'b1;
            HRESP  = 2'b00;
            HRDATA = '0;
        end
    end

    // Registered write - store data at posedge HCLK
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            // Reset memory (optional)
        end else if (valid_transfer && HWRITE) begin
            mem[HADDR[11:2]] <= HWDATA;
        end
    end
endmodule

`endif // AHB_SLAVE_RAM_SV
