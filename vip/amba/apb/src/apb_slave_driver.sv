`ifndef APB_SLAVE_DRIVER_SV
`define APB_SLAVE_DRIVER_SV

class apb_slave_driver extends uvm_driver #(apb_transaction);
    `uvm_component_utils(apb_slave_driver)

    virtual apb_interface vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_transaction rsp;
        forever begin
            // Wait for SETUP: PSEL=1, PENABLE=0
            @(vif.slave_cb);
            while (!(vif.slave_cb.PSEL && !vif.slave_cb.PENABLE))
                @(vif.slave_cb);

            // Get response from sequencer
            seq_item_port.get(rsp);

            // Wait for ACCESS: PENABLE=1, PREADY=1
            @(vif.slave_cb);
            while (!(vif.slave_cb.PENABLE && vif.PREADY))
                @(vif.slave_cb);

            // Drive response
            vif.slave_cb.PRDATA  <= rsp.data;
            vif.slave_cb.PSLVERR <= rsp.slverr;
        end
    endtask
endclass

`endif // APB_SLAVE_DRIVER_SV
