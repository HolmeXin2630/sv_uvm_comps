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

    extern function new(string name, uvm_component parent);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual function void connect_phase(uvm_phase phase);
    extern virtual function uvm_sequencer_base get_sequencer();
endclass

function ahb_slave_agent::new(string name, uvm_component parent);
    super.new(name, parent);
endfunction

function void ahb_slave_agent::build_phase(uvm_phase phase);
    virtual ahb_interface vif;
    super.build_phase(phase);

    if (cfg == null)
        `uvm_fatal("NOCFG", "Config not injected by parent")

    // Get vif from config_db, store into config object
    if (!uvm_config_db#(virtual ahb_interface)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", $sformatf("vif not set for %s", get_full_name()))
    cfg.vif = vif;

    // Create monitor (always)
    mon = ahb_monitor::type_id::create("mon", this);
    mon.cfg = cfg;

    // Create driver based on active config (uvc_gen pattern)
    if (cfg.is_active == UVM_ACTIVE) begin
        drv = ahb_slave_driver::type_id::create("drv", this);
        drv.cfg = cfg;
        sqr = ahb_slave_sequencer::type_id::create("sqr", this);
    end
endfunction

function void ahb_slave_agent::connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (cfg.is_active == UVM_ACTIVE) begin
        // Monitor → Sequencer FIFO (beat-level, for slave response sequence)
        mon.beat_ap.connect(sqr.request_fifo.analysis_export);
        // Driver ← Sequencer
        drv.seq_item_port.connect(sqr.seq_item_export);
    end
endfunction

function uvm_sequencer_base ahb_slave_agent::get_sequencer();
    return sqr;
endfunction

`endif // AHB_SLAVE_AGENT_SV
