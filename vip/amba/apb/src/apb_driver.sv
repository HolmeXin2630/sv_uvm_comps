`ifndef APB_DRIVER_SV
`define APB_DRIVER_SV

class apb_driver extends uvm_driver #(apb_transaction);
    `uvm_component_utils(apb_driver)

    virtual apb_interface.master vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_transaction txn;
        forever begin
            seq_item_port.get_next_item(txn);

            // Idle cycles
            repeat (txn.idle_cycles) @(vif.master_cb);

            // SETUP phase: PSEL=1, PENABLE=0
            @(vif.master_cb);
            vif.master_cb.PSEL    <= 1'b1;
            vif.master_cb.PENABLE <= 1'b0;
            vif.master_cb.PADDR   <= txn.addr;
            vif.master_cb.PWRITE  <= txn.write;
            if (txn.write)
                vif.master_cb.PWDATA <= txn.data;
            `ifdef APB_APB4_ENABLE
            vif.master_cb.PSTRB <= txn.strb;
            vif.master_cb.PPROT <= txn.prot;
            `endif

            // ACCESS phase: PENABLE=1
            @(vif.master_cb);
            vif.master_cb.PENABLE <= 1'b1;

            // Wait for PREADY
            while (!vif.master_cb.PREADY) @(vif.master_cb);

            // Sample response for read
            if (!txn.write)
                txn.data = vif.master_cb.PRDATA;
            txn.slverr = vif.master_cb.PSLVERR;

            // Return to IDLE
            @(vif.master_cb);
            vif.master_cb.PSEL    <= 1'b0;
            vif.master_cb.PENABLE <= 1'b0;

            seq_item_port.item_done();
        end
    endtask
endclass

`endif // APB_DRIVER_SV
