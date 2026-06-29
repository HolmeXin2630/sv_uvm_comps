`ifndef APB_PKG_SV
`define APB_PKG_SV

package hx_apb_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "apb_defines.svh"

    // Components
    `include "apb_transaction.sv"
    `include "apb_config.sv"
    `include "apb_sequencer.sv"
    `include "apb_monitor.sv"
    `include "apb_driver.sv"
    `include "apb_slave_driver.sv"
    `include "apb_agent.sv"
    `include "apb_sequences.sv"
    `include "apb_coverage.sv"
    `include "apb_scoreboard.sv"

endpackage

`endif // APB_PKG_SV
