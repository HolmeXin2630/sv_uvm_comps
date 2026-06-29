// vip/amba/ahb/tb/ahb_tb_pkg.sv
`ifndef AHB_TB_PKG_SV
`define AHB_TB_PKG_SV

package hx_ahb_tb_pkg;
    import uvm_pkg::*;
    import hx_ahb_pkg::*;
    `include "uvm_macros.svh"

    `include "ahb_base_test.sv"
    `include "ahb_lite_test.sv"
    `include "ahb_burst_test.sv"
    `include "ahb_pipeline_test.sv"
    `include "ahb_wait_state_test.sv"
    `include "ahb_error_resp_test.sv"

endpackage

`endif // AHB_TB_PKG_SV
