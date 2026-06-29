`ifndef APB_SLAVE_RAM_SV
`define APB_SLAVE_RAM_SV

module apb_slave_ram #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter WAIT_CYCLES = 0,
    parameter INJECT_ERROR = 0
) (
    input  logic                    PCLK,
    input  logic                    PRESETn,
    input  logic                    PSEL,
    input  logic                    PENABLE,
    input  logic                    PWRITE,
    input  logic [ADDR_WIDTH-1:0]   PADDR,
    input  logic [DATA_WIDTH-1:0]   PWDATA,
    output logic [DATA_WIDTH-1:0]   PRDATA,
    output logic                    PREADY,
    output logic                    PSLVERR
`ifdef APB_APB4_ENABLE
    ,input logic [DATA_WIDTH/8-1:0] PSTRB
`endif
);
    logic [DATA_WIDTH-1:0] mem [0:1023];
    int unsigned wait_cnt = 0;

    // Sequential output for read data (synchronized with PREADY)
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PRDATA <= '0;
        end else if (PSEL && PENABLE && !PWRITE && !INJECT_ERROR && wait_cnt >= WAIT_CYCLES) begin
            PRDATA <= mem[PADDR[11:2]];
        end else begin
            PRDATA <= '0;
        end
    end

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PREADY  <= 1'b0;
            PSLVERR <= 1'b0;
            wait_cnt <= 0;
        end else if (PSEL && PENABLE) begin
            if (wait_cnt < WAIT_CYCLES) begin
                PREADY <= 1'b0;
                wait_cnt <= wait_cnt + 1;
            end else begin
                PREADY <= 1'b1;
                wait_cnt <= 0;

                if (INJECT_ERROR) begin
                    PSLVERR <= 1'b1;
                end else begin
                    PSLVERR <= 1'b0;
                    if (PWRITE) begin
                    `ifdef APB_APB4_ENABLE
                        // Byte-lane write with PSTRB
                        for (int i = 0; i < DATA_WIDTH/8; i++) begin
                            if (PSTRB[i])
                                mem[PADDR[11:2]][i*8 +: 8] <= PWDATA[i*8 +: 8];
                        end
                    `else
                        mem[PADDR[11:2]] <= PWDATA;
                    `endif
                    end
                end
            end
        end else begin
            PREADY <= 1'b0;
            PSLVERR <= 1'b0;
        end
    end
endmodule

`endif // APB_SLAVE_RAM_SV
