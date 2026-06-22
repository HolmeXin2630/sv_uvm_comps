`ifndef APB_SLAVE_DRIVER_SV
`define APB_SLAVE_DRIVER_SV

class apb_slave_driver extends uvm_driver #(apb_transaction);
    `uvm_component_utils(apb_slave_driver)

    virtual apb_interface vif;  // 不使用 modport，使用 clocking block
    apb_agent_config cfg;

    extern function new(string name, uvm_component parent);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task run();
    extern virtual protected task get_and_drive();
    extern virtual protected task drive_trans(apb_transaction txn);
endclass

function apb_slave_driver::new(string name, uvm_component parent);
    super.new(name, parent);
endfunction

function void apb_slave_driver::build_phase(uvm_phase phase);
    super.build_phase(phase);
    vif = cfg.vif;  // VIF from config, not config_db
endfunction

// Reset-aware main loop (uvc_gen pattern)
task apb_slave_driver::run();
    fork begin  // Guard fork
        forever begin
            fork
                begin
                    @(posedge vif.PRESETn);
                    // Reset cleanup in driver (not via interface task)
                    vif.slave_cb.PRDATA  <= '0;
                    vif.slave_cb.PSLVERR <= 1'b0;
                    vif.slave_cb.PREADY  <= 1'b0;
                    get_and_drive();
                end
                begin
                    @(negedge vif.PRESETn);
                end
            join_any
            disable fork;
        end
    end join  // Guard fork
endtask

// Standard get_next_item loop
task apb_slave_driver::get_and_drive();
    forever begin
        seq_item_port.get_next_item(req);
        drive_trans(req);
        seq_item_port.item_done();
    end
endtask

// Protocol-specific driving
task apb_slave_driver::drive_trans(apb_transaction txn);
    // Wait for SETUP: PSEL=1, PENABLE=0
    @(vif.slave_cb);
    while (!(vif.slave_cb.PSEL && !vif.slave_cb.PENABLE))
        @(vif.slave_cb);

    // Wait for ACCESS: PENABLE=1
    @(vif.slave_cb);
    while (!vif.slave_cb.PENABLE)
        @(vif.slave_cb);

    // Drive response (slave_cb output signals)
    vif.slave_cb.PRDATA  <= txn.data;
    vif.slave_cb.PSLVERR <= txn.slverr;
    vif.slave_cb.PREADY  <= 1'b1;

    // Wait one cycle for response to be sampled
    @(vif.slave_cb);

    // Deassert PREADY
    vif.slave_cb.PREADY <= 1'b0;
endtask

`endif // APB_SLAVE_DRIVER_SV
