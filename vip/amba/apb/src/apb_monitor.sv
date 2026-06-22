`ifndef APB_MONITOR_SV
`define APB_MONITOR_SV

class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    virtual apb_interface vif;  // 不使用 modport，使用 clocking block
    apb_agent_config cfg;
    uvm_analysis_port #(apb_transaction) broadcaster;  // uvc_gen pattern: broadcaster not ap

    extern function new(string name, uvm_component parent);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task run();
    extern virtual task rcv_data_phase();
endclass

function apb_monitor::new(string name, uvm_component parent);
    super.new(name, parent);
    broadcaster = new("broadcaster", this);  // Created in new(), not build_phase
endfunction

function void apb_monitor::build_phase(uvm_phase phase);
    super.build_phase(phase);
    vif = cfg.vif;  // VIF from config
endfunction

// Reset-aware main loop (uvc_gen pattern)
task apb_monitor::run();
    fork begin
        forever begin
            fork
                begin
                    @(posedge vif.PRESETn);
                    rcv_data_phase();
                end
                begin
                    @(negedge vif.PRESETn);
                end
            join_any
            disable fork;
        end
    end join
endtask

// Protocol-specific monitoring
task apb_monitor::rcv_data_phase();
    apb_transaction txn;
    forever begin
        // Wait for SETUP: PSEL=1, PENABLE=0
        @(vif.monitor_cb);
        while (!(vif.monitor_cb.PSEL && !vif.monitor_cb.PENABLE))
            @(vif.monitor_cb);

        // Sample address and control
        txn = apb_transaction::type_id::create("txn");
        txn.addr  = vif.monitor_cb.PADDR;
        txn.write = vif.monitor_cb.PWRITE;
        `ifdef APB_APB4_ENABLE
        txn.strb  = vif.monitor_cb.PSTRB;
        txn.prot  = vif.monitor_cb.PPROT;
        `endif

        if (txn.write)
            txn.data = vif.monitor_cb.PWDATA;

        // Wait for ACCESS completion: PENABLE=1, PREADY=1
        @(vif.monitor_cb);
        while (!(vif.monitor_cb.PENABLE && vif.monitor_cb.PREADY))
            @(vif.monitor_cb);

        // Sample response
        if (!txn.write)
            txn.data = vif.monitor_cb.PRDATA;
        txn.slverr = vif.monitor_cb.PSLVERR;

        // Send to analysis port
        broadcaster.write(txn);
    end
endtask

`endif // APB_MONITOR_SV
