// vip/amba/ahb/src/ahb_master_agent.sv
`ifndef AHB_MASTER_AGENT_SV
`define AHB_MASTER_AGENT_SV

class ahb_master_agent extends uvm_agent;
    `uvm_component_utils(ahb_master_agent)

    // Exposed API
    ahb_agent_config cfg;
    ahb_sequencer    sqr;

    // Internal
    ahb_master_driver drv;
    ahb_monitor       mon;

    // vif
    virtual ahb_interface vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get vif from config_db
        if (!uvm_config_db#(virtual ahb_interface)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", $sformatf("vif not set for %s", get_full_name()))

        // Create components
        if (cfg.active) begin
            drv = ahb_master_driver::type_id::create("drv", this);
            sqr = ahb_sequencer::type_id::create("sqr", this);
        end
        mon = ahb_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Pass vif
        mon.vif = vif;
        if (cfg.active) begin
            drv.vif = vif;
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction
endclass

`endif // AHB_MASTER_AGENT_SV
