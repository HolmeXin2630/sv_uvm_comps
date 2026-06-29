// vip/amba/ahb/src/ahb_agent_config.sv
`ifndef AHB_AGENT_CONFIG_SV
`define AHB_AGENT_CONFIG_SV

class ahb_agent_config extends uvm_object;
    `uvm_object_utils(ahb_agent_config)

    // Mode
    bit active = 1;  // 1=active, 0=passive

    // Width
    int addr_width = `AHB_ADDR_WIDTH;
    int data_width = `AHB_DATA_WIDTH;

    // AHB5 enable
    bit ahb5_enable = 0;

    // Wait cycles (for slave)
    int unsigned wait_cycles = 0;

    // Virtual interface (set by tb_top via config_db)
    virtual ahb_interface vif;

    function new(string name = "ahb_agent_config");
        super.new(name);
    endfunction
endclass

`endif // AHB_AGENT_CONFIG_SV
