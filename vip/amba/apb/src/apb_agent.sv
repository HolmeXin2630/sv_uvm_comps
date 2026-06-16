`ifndef APB_AGENT_SV
`define APB_AGENT_SV

class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    // Exposed API
    apb_agent_config cfg;
    apb_sequencer    sqr;

    // Internal
    apb_driver       drv;
    apb_slave_driver slave_drv;
    apb_monitor      mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get vif from config_db
        if (!uvm_config_db#(virtual apb_interface)::get(this, "", "vif", cfg.vif))
            `uvm_fatal("NOVIF", "Virtual interface not set for apb_agent")

        // Create monitor (always)
        mon = apb_monitor::type_id::create("mon", this);

        // Create driver based on active config
        if (cfg.active) begin
            if (cfg.master_mode) begin
                drv = apb_driver::type_id::create("drv", this);
                sqr = apb_sequencer::type_id::create("sqr", this);
            end else begin
                slave_drv = apb_slave_driver::type_id::create("slave_drv", this);
                sqr = apb_sequencer::type_id::create("sqr", this);
            end
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Pass vif to components
        mon.vif = cfg.vif;
        if (cfg.active) begin
            if (cfg.master_mode) begin
                drv.vif = cfg.vif;
                drv.seq_item_port.connect(sqr.seq_item_export);
            end else begin
                slave_drv.vif = cfg.vif;
                slave_drv.seq_item_port.connect(sqr.seq_item_export);
            end
        end
    endfunction
endclass

`endif // APB_AGENT_SV
