// vip/amba/ahb/test/ahb_base_test.sv
`ifndef AHB_BASE_TEST_SV
`define AHB_BASE_TEST_SV

class ahb_base_test extends uvm_test;
    `uvm_component_utils(ahb_base_test)

    ahb_bus_env      env;
    ahb_env_config   env_cfg;

    function new(string name = "ahb_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env_cfg = ahb_env_config::type_id::create("env_cfg");
        env_cfg.init();

        env = ahb_bus_env::type_id::create("env", this);
        env.env_cfg = env_cfg;
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction
endclass

`endif // AHB_BASE_TEST_SV
