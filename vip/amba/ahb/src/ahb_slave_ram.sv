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

    logic valid_transfer;
    assign valid_transfer = HSEL && (HTRANS inside {2'b10, 2'b11});

    // Pipeline registers
    logic                    dphase_valid;
    logic                    dphase_write;
    logic [ADDR_WIDTH-1:0]   dphase_addr;
    logic                    dphase_error;
    int unsigned             wait_cnt;

    // Internal response (computed in data phase, registered)
    logic                    resp_valid;
    logic [DATA_WIDTH-1:0]   resp_rdata;
    logic                    resp_ready;
    logic [1:0]              resp_hresp;

    // Stage 1: Pipeline processing
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            dphase_valid <= 0; dphase_write <= 0; dphase_addr <= '0;
            dphase_error <= 0; wait_cnt <= 0;
            resp_valid <= 0; resp_rdata <= '0; resp_ready <= 1; resp_hresp <= 0;
        end else begin
            resp_valid <= 0;
            resp_ready <= 1;
            resp_hresp <= 0;

            if (dphase_valid) begin
                if (wait_cnt > 0) begin
                    resp_ready <= 0;
                    wait_cnt <= wait_cnt - 1;
                end else begin
                    resp_valid <= 1;
                    resp_hresp <= dphase_error ? 1 : 0;
                    if (!dphase_error && !dphase_write)
                        resp_rdata <= mem[dphase_addr[11:2]];
                    else if (!dphase_error && dphase_write)
                        mem[dphase_addr[11:2]] <= HWDATA;
                    dphase_valid <= 0;
                end
            end

            if (valid_transfer && !dphase_valid) begin
                dphase_valid <= 1;
                dphase_write <= HWRITE;
                dphase_addr  <= HADDR;
                dphase_error <= INJECT_ERROR;
                wait_cnt     <= WAIT_CYCLES;
            end
        end
    end

    // Stage 2: Output register (one cycle delay, visible to clocking block)
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HREADY <= 1; HRESP <= 0; HRDATA <= '0;
        end else begin
            HREADY <= resp_ready;
            HRESP  <= resp_hresp;
            if (resp_valid)
                HRDATA <= resp_rdata;
            // HRDATA is sticky: holds last read data
        end
    end

endmodule

`endif // AHB_SLAVE_RAM_SV
