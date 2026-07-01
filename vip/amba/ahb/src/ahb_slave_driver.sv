// vip/amba/ahb/src/ahb_slave_driver.sv
`ifndef AHB_SLAVE_DRIVER_SV
`define AHB_SLAVE_DRIVER_SV

class ahb_slave_driver extends uvm_driver #(ahb_transaction);
    `uvm_component_utils(ahb_slave_driver)

    virtual ahb_interface vif;
    ahb_agent_config cfg;

    extern function new(string name, uvm_component parent);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task run();
    extern virtual protected task get_and_drive();
    extern virtual protected task drive_response(ahb_transaction rsp);
endclass

function ahb_slave_driver::new(string name, uvm_component parent);
    super.new(name, parent);
endfunction

function void ahb_slave_driver::build_phase(uvm_phase phase);
    super.build_phase(phase);
    vif = cfg.vif;
endfunction

// Reset-aware main loop
task ahb_slave_driver::run();
    fork begin
        forever begin
            fork
                begin
                    @(posedge vif.HRESETn);
                    vif.reset_slave_signals();
                    get_and_drive();
                end
                begin
                    @(negedge vif.HRESETn);
                end
            join_any
            disable fork;
        end
    end join
endtask

task ahb_slave_driver::get_and_drive();
    forever begin
        ahb_transaction rsp;
        // Wait for valid address phase (NONSEQ/SEQ) using clocking block
        @(vif.slave_cb);
        while (!(vif.slave_cb.HTRANS inside {2'b10, 2'b11}))
            @(vif.slave_cb);

        // Wait for data phase (one cycle after address phase)
        @(vif.slave_cb);

        // Get response from sequencer and drive in data phase
        seq_item_port.get_next_item(rsp);
        drive_response(rsp);
        seq_item_port.item_done(rsp);
    end
endtask

task ahb_slave_driver::drive_response(ahb_transaction rsp);
    // Insert wait states (drive HREADY low via clocking block)
    repeat (rsp.wait_cycles) begin
        vif.slave_cb.HREADY <= 1'b0;
        @(vif.slave_cb);
    end

    // Drive response in data phase (all via clocking block)
    vif.slave_cb.HREADY <= 1'b1;
    if (rsp.xact_type == READ)
        vif.slave_cb.HRDATA <= rsp.data[0];
    vif.slave_cb.HRESP <= rsp.hresp;

    @(vif.slave_cb);
endtask

`endif // AHB_SLAVE_DRIVER_SV
