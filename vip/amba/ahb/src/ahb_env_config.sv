// vip/amba/ahb/src/ahb_env_config.sv
`ifndef AHB_ENV_CONFIG_SV
`define AHB_ENV_CONFIG_SV

class ahb_env_config extends uvm_object;
    `uvm_object_utils(ahb_env_config)

    // Agent counts
    int master_agt_num = 1;
    int slave_agt_num  = 1;
    bit ahb_lite = 1;

    // Agent configs (composition)
    ahb_agent_config master_cfg[];
    ahb_agent_config slave_cfg[];

    // Slave address map
    bit [`AHB_ADDR_WIDTH-1:0] slave_base_addr[];
    bit [`AHB_ADDR_WIDTH-1:0] slave_size[];

    function new(string name = "ahb_env_config");
        super.new(name);
    endfunction

    // Initialize
    function void init();
        master_cfg = new[master_agt_num];
        slave_cfg  = new[slave_agt_num];
        slave_base_addr = new[slave_agt_num];
        slave_size = new[slave_agt_num];

        foreach (master_cfg[i])
            master_cfg[i] = ahb_agent_config::type_id::create($sformatf("master_cfg[%0d]", i));
        foreach (slave_cfg[i]) begin
            slave_cfg[i] = ahb_agent_config::type_id::create($sformatf("slave_cfg[%0d]", i));
            slave_cfg[i].is_active = UVM_PASSIVE;  // DUT drives responses
            slave_base_addr[i] = i * 'h1000;
            slave_size[i] = 'h1000;
        end
    endfunction

    // AHB-Lite shortcut
    function void init_lite();
        ahb_lite = 1;
        master_agt_num = 1;
        init();
    endfunction
endclass

`endif // AHB_ENV_CONFIG_SV
