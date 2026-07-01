// vip/amba/ahb/src/ahb_bus_env.sv
`ifndef AHB_BUS_ENV_SV
`define AHB_BUS_ENV_SV

class ahb_bus_env extends uvm_env;
    `uvm_component_utils(ahb_bus_env)

    // Exposed API
    ahb_env_config env_cfg;

    // Internal components
    ahb_master_agent master_agt[];
    ahb_slave_agent  slave_agt[];
    ahb_scoreboard   scb;
    ahb_agent_coverage master_cov[];
    ahb_agent_coverage slave_cov[];

    extern function new(string name = "ahb_bus_env", uvm_component parent = null);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual function void connect_phase(uvm_phase phase);
endclass

function ahb_bus_env::new(string name = "ahb_bus_env", uvm_component parent = null);
    super.new(name, parent);
endfunction

function void ahb_bus_env::build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get env_cfg from config_db if not already set
    if (env_cfg == null) begin
        if (!uvm_config_db#(ahb_env_config)::get(this, "", "env_cfg", env_cfg))
            `uvm_fatal("NOCONFIG", "ahb_env_config not set")
    end

    // Create master agents and inject config (before agent's build_phase)
    master_agt = new[env_cfg.master_agt_num];
    foreach (master_agt[i]) begin
        master_agt[i] = ahb_master_agent::type_id::create(
            $sformatf("master_agt[%0d]", i), this);
        master_agt[i].cfg = env_cfg.master_cfg[i];
    end

    // Create slave agents and inject config (before agent's build_phase)
    slave_agt = new[env_cfg.slave_agt_num];
    foreach (slave_agt[i]) begin
        slave_agt[i] = ahb_slave_agent::type_id::create(
            $sformatf("slave_agt[%0d]", i), this);
        slave_agt[i].cfg = env_cfg.slave_cfg[i];
    end

    // Create scoreboard
    scb = ahb_scoreboard::type_id::create("scb", this);

    // Create coverage
    master_cov = new[env_cfg.master_agt_num];
    foreach (master_cov[i])
        master_cov[i] = ahb_agent_coverage::type_id::create(
            $sformatf("master_cov[%0d]", i), this);
    slave_cov = new[env_cfg.slave_agt_num];
    foreach (slave_cov[i])
        slave_cov[i] = ahb_agent_coverage::type_id::create(
            $sformatf("slave_cov[%0d]", i), this);
endfunction

function void ahb_bus_env::connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect scoreboard (burst-level comparison)
    foreach (master_agt[i])
        master_agt[i].mon.burst_ap.connect(scb.master_export);
    foreach (slave_agt[i])
        slave_agt[i].mon.burst_ap.connect(scb.slave_export);

    // Connect coverage (beat-level)
    foreach (master_agt[i])
        master_agt[i].mon.beat_ap.connect(master_cov[i].analysis_export);
    foreach (slave_agt[i])
        slave_agt[i].mon.beat_ap.connect(slave_cov[i].analysis_export);
endfunction

`endif // AHB_BUS_ENV_SV
