// vip/amba/ahb/src/ahb_slave_driver.sv
`ifndef AHB_SLAVE_DRIVER_SV
`define AHB_SLAVE_DRIVER_SV

class ahb_slave_driver extends uvm_driver #(ahb_transaction);
    `uvm_component_utils(ahb_slave_driver)

    virtual ahb_interface vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        ahb_transaction rsp;
        forever begin
            // Wait for valid transfer (sample directly, HREADY is output of slave)
            @(vif.slave_cb);
            while (!(vif.slave_cb.HTRANS inside {2'b10, 2'b11} && vif.HREADY))
                @(vif.slave_cb);

            // Get response from sequencer
            seq_item_port.get(rsp);

            // Insert wait states
            repeat (rsp.wait_cycles) begin
                vif.slave_cb.HREADY <= 1'b0;
                @(vif.slave_cb);
            end

            // Drive response
            vif.slave_cb.HREADY <= 1'b1;
            if (rsp.xact_type == READ)
                vif.slave_cb.HRDATA <= rsp.data[0];
            vif.slave_cb.HRESP <= rsp.hresp;
        end
    endtask
endclass

`endif // AHB_SLAVE_DRIVER_SV
