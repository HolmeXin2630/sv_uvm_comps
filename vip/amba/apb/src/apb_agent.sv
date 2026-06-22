`ifndef APB_AGENT_SV
`define APB_AGENT_SV

class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    // Exposed API
    apb_agent_config cfg;
    apb_sequencer    sqr;
    uvm_analysis_port #(apb_transaction) mon_ap;  // Exposed monitor analysis port

    // Internal
    apb_driver       drv;
    apb_slave_driver slave_drv;
    apb_monitor      mon;

    extern function new(string name, uvm_component parent);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual function void connect_phase(uvm_phase phase);
    extern virtual task run_phase(uvm_phase phase);
endclass

function apb_agent::new(string name, uvm_component parent);
    super.new(name, parent);
    mon_ap = new("mon_ap", this);
endfunction

function void apb_agent::build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get vif from config_db
    if (!uvm_config_db#(virtual apb_interface)::get(this, "", "vif", cfg.vif))
        `uvm_fatal("NOVIF", "Virtual interface not set for apb_agent")

    // Create monitor (always)
    mon = apb_monitor::type_id::create("mon", this);
    mon.cfg = cfg;

    // Create driver based on active config (uvc_gen pattern)
    if (cfg.is_active == UVM_ACTIVE) begin
        if (cfg.master_mode) begin
            drv = apb_driver::type_id::create("drv", this);
            drv.cfg = cfg;
            sqr = apb_sequencer::type_id::create("sqr", this);
        end else begin
            slave_drv = apb_slave_driver::type_id::create("slave_drv", this);
            slave_drv.cfg = cfg;
            sqr = apb_sequencer::type_id::create("sqr", this);
        end
    end
endfunction

function void apb_agent::connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect monitor analysis port to exposed port
    mon.broadcaster.connect(mon_ap);

    // Connect driver to sequencer
    if (cfg.is_active == UVM_ACTIVE) begin
        if (cfg.master_mode) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end else begin
            slave_drv.seq_item_port.connect(sqr.seq_item_export);
        end
    end
endfunction

// Agent controls driver/monitor lifecycle (uvc_gen pattern)
task apb_agent::run_phase(uvm_phase phase);
    fork
        mon.run();
        if (cfg.is_active == UVM_ACTIVE) begin
            if (cfg.master_mode)
                drv.run();
            else
                slave_drv.run();
        end
    join
endtask

`endif // APB_AGENT_SV
