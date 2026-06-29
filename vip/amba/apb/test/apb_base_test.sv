`ifndef APB_BASE_TEST_SV
`define APB_BASE_TEST_SV

class apb_base_test extends uvm_test;
    `uvm_component_utils(apb_base_test)

    // Components
    apb_agent         apb_agt;
    apb_scoreboard    scb;
    apb_coverage      cov;
    apb_system_config sys_cfg;

    function new(string name = "apb_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Create system config
        sys_cfg = apb_system_config::type_id::create("sys_cfg");
        sys_cfg.init();

        // Create agent
        apb_agt = apb_agent::type_id::create("apb_agt", this);

        // Inject config (dependency injection)
        apb_agt.cfg = sys_cfg.master_cfg;

        // Create scoreboard and coverage
        scb = apb_scoreboard::type_id::create("scb", this);
        cov = apb_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        apb_agt.mon_ap.connect(scb.ap);
        apb_agt.mon_ap.connect(cov.analysis_export);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction
endclass

`endif // APB_BASE_TEST_SV
