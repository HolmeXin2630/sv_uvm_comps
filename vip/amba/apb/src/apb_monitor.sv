`ifndef APB_MONITOR_SV
`define APB_MONITOR_SV

class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    virtual apb_interface.monitor vif;
    uvm_analysis_port #(apb_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    task run_phase(uvm_phase phase);
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
            ap.write(txn);
        end
    endtask
endclass

`endif // APB_MONITOR_SV
