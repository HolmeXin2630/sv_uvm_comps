// vip/amba/ahb/src/ahb_slave_agent.sv
`ifndef AHB_SLAVE_AGENT_SV
`define AHB_SLAVE_AGENT_SV

class ahb_slave_agent extends uvm_agent;
    `uvm_component_utils(ahb_slave_agent)

    // Exposed API
    ahb_agent_config    cfg;
    ahb_slave_sequencer sqr;

    // Internal
    ahb_slave_driver drv;
    ahb_monitor      mon;

    // vif
    virtual ahb_interface vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual ahb_interface)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", $sformatf("vif not set for %s", get_full_name()))

        if (cfg.active) begin
            drv = ahb_slave_driver::type_id::create("drv", this);
            sqr = ahb_slave_sequencer::type_id::create("sqr", this);
        end
        mon = ahb_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        mon.vif = vif;
        if (cfg.active) begin
            drv.vif = vif;
            // Monitor → Sequencer FIFO (beat-level)
            mon.beat_ap.connect(sqr.request_fifo.analysis_export);
            // Driver ← Sequencer
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction
endclass

`endif // AHB_SLAVE_AGENT_SV
