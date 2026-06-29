// vip/amba/ahb/src/ahb_master_driver.sv
`ifndef AHB_MASTER_DRIVER_SV
`define AHB_MASTER_DRIVER_SV

class ahb_master_driver extends uvm_driver #(ahb_transaction);
    `uvm_component_utils(ahb_master_driver)

    virtual ahb_interface vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        ahb_transaction txn;
        // Wait for reset to complete
        @(posedge vif.HRESETn);
        forever begin
            seq_item_port.get_next_item(txn);
            drive_transaction(txn);
            seq_item_port.item_done(txn);
        end
    endtask

    task drive_transaction(ahb_transaction txn);
        // Drive address phase at negedge HCLK (avoid race with slave)
        @(negedge vif.HCLK);
        vif.HADDR     = txn.addr;
        vif.HTRANS    = txn.is_first_beat ? 2'b10 : 2'b11;  // NONSEQ : SEQ
        vif.HSIZE     = txn.burst_size;
        vif.HBURST    = txn.burst_type;
        vif.HWRITE    = txn.xact_type;
        vif.HPROT     = txn.prot;
        vif.HMASTLOCK = 1'b0;

        // Write: drive HWDATA in same cycle as address
        if (txn.xact_type == WRITE)
            vif.HWDATA = txn.data[0];

        // Wait for HREADY - slave may insert wait states
        @(posedge vif.HCLK);
        while (!vif.HREADY) @(posedge vif.HCLK);

        // Read: sample HRDATA when HREADY is high
        if (txn.xact_type == READ)
            txn.data[0] = vif.HRDATA;

        // Sample response
        txn.hresp = hresp_e'(vif.HRESP);
    endtask
endclass

`endif // AHB_MASTER_DRIVER_SV
