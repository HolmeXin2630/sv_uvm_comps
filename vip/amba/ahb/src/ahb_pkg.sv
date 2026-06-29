// vip/amba/ahb/src/ahb_pkg.sv
`ifndef AHB_PKG_SV
`define AHB_PKG_SV

`include "ahb_defines.svh"
`include "ahb_interface.sv"

package hx_ahb_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "ahb_transaction.sv"
    `include "ahb_agent_config.sv"
    `include "ahb_env_config.sv"
    `include "ahb_sequencer.sv"
    `include "ahb_monitor.sv"
    `include "ahb_master_driver.sv"
    `include "ahb_slave_driver.sv"
    `include "ahb_master_agent.sv"
    `include "ahb_slave_agent.sv"
    `include "ahb_scoreboard.sv"
    `include "ahb_agent_coverage.sv"
    `include "ahb_bus_env.sv"
    `include "ahb_sequences.sv"

endpackage

`endif // AHB_PKG_SV
