// vip/amba/ahb/src/ahb_master_driver.sv
`ifndef AHB_MASTER_DRIVER_SV
`define AHB_MASTER_DRIVER_SV

class ahb_master_driver extends uvm_driver #(ahb_transaction);
    `uvm_component_utils(ahb_master_driver)

    virtual ahb_interface vif;
    ahb_agent_config cfg;

    extern function new(string name, uvm_component parent);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task run();
    extern virtual protected task get_and_drive();
    extern virtual protected task drive_transaction(ahb_transaction txn);
endclass

function ahb_master_driver::new(string name, uvm_component parent);
    super.new(name, parent);
endfunction

function void ahb_master_driver::build_phase(uvm_phase phase);
    super.build_phase(phase);
    vif = cfg.vif;
endfunction

// Reset-aware main loop
task ahb_master_driver::run();
    fork begin
        forever begin
            fork
                begin
                    @(posedge vif.HRESETn);
                    vif.reset_master_signals();
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

task ahb_master_driver::get_and_drive();
    forever begin
        ahb_transaction txn;
        seq_item_port.get_next_item(txn);
        drive_transaction(txn);
        seq_item_port.item_done(txn);
    end
endtask

// Drive one beat with proper AHB pipeline timing
// Address phase: posedge HCLK (via master_cb)
// Data phase:    next posedge HCLK (HWDATA one cycle after address)
task ahb_master_driver::drive_transaction(ahb_transaction txn);
    // === Address phase ===
    @(vif.master_cb);
    vif.master_cb.HADDR     <= txn.addr;
    vif.master_cb.HTRANS    <= txn.is_first_beat ? 2'b10 : 2'b11;  // NONSEQ : SEQ
    vif.master_cb.HSIZE     <= txn.burst_size;
    vif.master_cb.HBURST    <= txn.burst_type;
    vif.master_cb.HWRITE    <= txn.xact_type;
    vif.master_cb.HPROT     <= txn.prot;
    vif.master_cb.HMASTLOCK <= 1'b0;

    // Drive write data in address phase via blocking assignment.
    // Must be blocking so monitor (direct access) sees the value at the same posedge.
    // DUT latches HWDATA in data phase (next posedge), so blocking is safe here.
    if (txn.xact_type == WRITE)
        vif.HWDATA = txn.data[0];

    // === Data phase (one cycle after address) ===
    @(vif.master_cb);

    // Wait for HREADY (clocking block: HREADY registered from previous cycle)
    while (!vif.master_cb.HREADY)
        @(vif.master_cb);

    // DUT two-stage pipeline: Stage 1 computes in cycle N, Stage 2 registers
    // in cycle N+1 (NBA). Need two extra posedges for Stage 2 output to settle.
    @(vif.master_cb);
    @(vif.master_cb);

    // Sample HRDATA via direct signal access (clocking block input sampling
    // occurs before NBA region and cannot see DUT's always_ff outputs).
    if (txn.xact_type == READ)
        txn.data[0] = vif.HRDATA;

    // Sample response
    txn.hresp = hresp_e'(vif.master_cb.HRESP);

    // Set bus to IDLE after last beat's data phase completes
    if (txn.is_last_beat)
        vif.master_cb.HTRANS <= 2'b00;  // IDLE
endtask

`endif // AHB_MASTER_DRIVER_SV
