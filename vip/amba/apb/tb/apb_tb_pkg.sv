`ifndef APB_TB_PKG_SV
`define APB_TB_PKG_SV

package hx_apb_tb_pkg;
    import uvm_pkg::*;
    import hx_apb_pkg::*;
    `include "uvm_macros.svh"

    // TODO: `include tb 文件
    // `include "apb_slave_ram.sv"

    `include "apb_base_test.sv"
    `include "apb_smoke_test.sv"
    `include "apb_wait_state_test.sv"
    `include "apb_slverr_test.sv"
    `include "apb_random_test.sv"
    `include "apb_directed_test.sv"
    `include "apb_reset_test.sv"

endpackage

`endif // APB_TB_PKG_SV
