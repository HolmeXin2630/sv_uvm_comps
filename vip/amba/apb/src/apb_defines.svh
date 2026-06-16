`ifndef APB_DEFINES_SVH
`define APB_DEFINES_SVH

// Width macros (can be overridden at compile time)
`ifndef APB_ADDR_WIDTH
`define APB_ADDR_WIDTH 32
`endif

`ifndef APB_DATA_WIDTH
`define APB_DATA_WIDTH 32
`endif

// Protocol version control
// `define APB_APB4_ENABLE  // Uncomment to enable APB4 features

`endif // APB_DEFINES_SVH
