`ifndef APB_DRIVER_SV
`define APB_DRIVER_SV

class apb_driver extends uvm_driver #(apb_transaction);
    `uvm_component_utils(apb_driver)

    virtual apb_interface vif;  // 不使用 modport，使用 clocking block
    apb_agent_config cfg;

    extern function new(string name, uvm_component parent);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task run();
    extern virtual protected task get_and_drive();
    extern virtual protected task drive_trans(apb_transaction txn);
endclass

function apb_driver::new(string name, uvm_component parent);
    super.new(name, parent);
endfunction

function void apb_driver::build_phase(uvm_phase phase);
    super.build_phase(phase);
    vif = cfg.vif;  // VIF from config, not config_db
endfunction

// Reset-aware main loop (uvc_gen pattern)
task apb_driver::run();
    fork begin  // Guard fork
        forever begin
            fork
                begin
                    @(posedge vif.PRESETn);
                    // Reset cleanup in driver (not via interface task)
                    vif.master_cb.PSEL    <= 1'b0;
                    vif.master_cb.PENABLE <= 1'b0;
                    vif.master_cb.PADDR   <= '0;
                    vif.master_cb.PWRITE  <= 1'b0;
                    vif.master_cb.PWDATA  <= '0;
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
task apb_driver::get_and_drive();
    forever begin
        seq_item_port.get_next_item(req);
        drive_trans(req);
        seq_item_port.item_done();
    end
endtask

// Protocol-specific driving
task apb_driver::drive_trans(apb_transaction txn);
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
endtask

`endif // APB_DRIVER_SV
