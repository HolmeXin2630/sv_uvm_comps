`ifndef APB_CONFIG_SV
`define APB_CONFIG_SV

// Agent Config
class apb_agent_config extends uvm_object;
    `uvm_object_utils(apb_agent_config)

    // Agent behavior (uvc_gen pattern)
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    bit has_coverage = 1;
    bit has_scoreboard = 1;

    // APB-specific: master/slave mode
    bit master_mode = 1; // 1=master, 0=slave

    // Width
    int addr_width = `APB_ADDR_WIDTH;
    int data_width = `APB_DATA_WIDTH;

    // APB4 enable
    bit apb4_enable = 0;

    // Virtual interface (set by tb_top via config_db)
    virtual apb_interface vif;

    function new(string name = "apb_agent_config");
        super.new(name);
    endfunction

    // Convenience methods for common configurations
    static function apb_agent_config create_master(string name = "apb_agent_config");
        apb_agent_config cfg = new(name);
        cfg.is_active = UVM_ACTIVE;
        cfg.master_mode = 1;
        return cfg;
    endfunction

    static function apb_agent_config create_slave(string name = "apb_agent_config");
        apb_agent_config cfg = new(name);
        cfg.is_active = UVM_ACTIVE;
        cfg.master_mode = 0;
        return cfg;
    endfunction

    static function apb_agent_config create_passive(string name = "apb_agent_config");
        apb_agent_config cfg = new(name);
        cfg.is_active = UVM_PASSIVE;
        return cfg;
    endfunction
endclass

// System Config
class apb_system_config extends uvm_object;
    `uvm_object_utils(apb_system_config)

    // Number of slaves
    int num_slaves = 1;

    // Agent configs
    apb_agent_config master_cfg;
    apb_agent_config slave_cfg[];

    // Slave address map: {base_addr, size} pairs
    bit [`APB_ADDR_WIDTH-1:0] slave_base_addr[];
    bit [`APB_ADDR_WIDTH-1:0] slave_size[];

    function new(string name = "apb_system_config");
        super.new(name);
    endfunction

    // Initialize
    function void init();
        master_cfg = apb_agent_config::create_master("master_cfg");

        slave_cfg = new[num_slaves];
        slave_base_addr = new[num_slaves];
        slave_size = new[num_slaves];

        foreach (slave_cfg[i]) begin
            slave_cfg[i] = apb_agent_config::create_slave($sformatf("slave_cfg[%0d]", i));
            slave_base_addr[i] = i * 'h1000;
            slave_size[i] = 'h1000;
        end
    endfunction
endclass

`endif // APB_CONFIG_SV
