// vip/amba/ahb/src/ahb_defines.svh
`ifndef AHB_DEFINES_SVH
`define AHB_DEFINES_SVH

// Width macros (can be overridden at compile time)
`ifndef AHB_ADDR_WIDTH
`define AHB_ADDR_WIDTH 32
`endif

`ifndef AHB_DATA_WIDTH
`define AHB_DATA_WIDTH 32
`endif

// Protocol version control
// `define AHB_AHB5_ENABLE  // Uncomment to enable AHB5 features

`endif // AHB_DEFINES_SVH
