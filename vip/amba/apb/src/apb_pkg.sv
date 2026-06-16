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
    // TODO: `include remaining components
    // ...

endpackage

`endif // APB_PKG_SV
