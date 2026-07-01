// vip/amba/ahb/src/ahb_monitor.sv
`ifndef AHB_MONITOR_SV
`define AHB_MONITOR_SV

class ahb_monitor extends uvm_monitor;
    `uvm_component_utils(ahb_monitor)

    virtual ahb_interface vif;
    ahb_agent_config cfg;

    // Dual analysis ports
    uvm_analysis_port #(ahb_transaction) beat_ap;   // Per-beat (coverage, slave sequence)
    uvm_analysis_port #(ahb_transaction) burst_ap;  // Per-burst (scoreboard)

    // Burst context
    ahb_transaction beat_buffer[$];
    int unsigned beat_count;
    bit in_burst;

    // Pipeline state for write data alignment
    // HWDATA appears one cycle after address phase in AHB protocol
    bit                      pending_valid;
    bit                      pending_is_write;
    ahb_transaction          pending_txn;


    extern function new(string name, uvm_component parent);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task run();
    extern virtual task collect_trans();
    extern virtual function ahb_transaction assemble_burst(ahb_transaction buffer[$]);
    extern virtual function bit is_burst_complete(ahb_transaction txn);
endclass

function ahb_monitor::new(string name, uvm_component parent);
    super.new(name, parent);
    beat_ap  = new("beat_ap", this);
    burst_ap = new("burst_ap", this);
endfunction

function void ahb_monitor::build_phase(uvm_phase phase);
    super.build_phase(phase);
    vif = cfg.vif;
endfunction

// Reset-aware main loop
task ahb_monitor::run();
    fork begin
        forever begin
            fork
                begin
                    @(posedge vif.HRESETn);
                    // Reset state
                    beat_buffer.delete();
                    beat_count = 0;
                    in_burst = 0;
                    pending_valid = 0;
                    pending_txn = null;
                    collect_trans();
                end
                begin
                    @(negedge vif.HRESETn);
                end
            join_any
            disable fork;
        end
    end join
endtask

task ahb_monitor::collect_trans();
    forever begin
        @(vif.monitor_cb);

        // --- Finalize previous transfer when HREADY is high ---
        // Use direct access for HREADY (slave driver uses blocking assignment)
        if (pending_valid && vif.HREADY) begin
            // For READ: sample HRDATA via direct access (clocking block sees pre-NBA stale values)
            if (!pending_is_write)
                pending_txn.data[0] = vif.HRDATA;

            // Sample response
            pending_txn.hresp = hresp_e'(vif.monitor_cb.HRESP);

            // Update burst context
            if (pending_txn.is_first_beat) begin
                // Flush previous INCR burst if interrupted by new NONSEQ
                if (beat_buffer.size() > 0 && in_burst)
                    burst_ap.write(assemble_burst(beat_buffer));
                beat_buffer.delete();
                beat_count = 0;
                in_burst = 1;
            end else begin
                beat_count++;
            end
            pending_txn.beat_num     = beat_count;
            pending_txn.burst_length = pending_txn.get_burst_length();

            // Send beat
            beat_ap.write(pending_txn);

            // Buffer for burst assembly
            beat_buffer.push_back(pending_txn);

            // Check burst completion (fixed length)
            if (is_burst_complete(pending_txn)) begin
                burst_ap.write(assemble_burst(beat_buffer));
                beat_buffer.delete();
                in_burst = 0;
            end
        end

        // --- Detect new address phase (NONSEQ/SEQ) ---
        if (vif.monitor_cb.HTRANS inside {2'b10, 2'b11}) begin
            pending_txn = ahb_transaction::type_id::create("txn");

            // Sample address/control signals
            pending_txn.addr        = vif.monitor_cb.HADDR;
            pending_txn.xact_type   = vif.monitor_cb.HWRITE ? WRITE : READ;
            pending_txn.burst_type  = hburst_e'(vif.monitor_cb.HBURST);
            pending_txn.burst_size  = hsize_e'(vif.monitor_cb.HSIZE);
            pending_txn.prot        = vif.monitor_cb.HPROT;

            pending_txn.is_first_beat = (vif.monitor_cb.HTRANS == 2'b10);  // NONSEQ

            // Capture write data via direct access (clocking block sees pre-NBA stale values)
            if (vif.monitor_cb.HWRITE) begin
                pending_txn.data = new[1];
                pending_txn.data[0] = vif.HWDATA;
            end

            pending_is_write  = vif.monitor_cb.HWRITE;
            pending_valid     = 1;
        end

        // --- Flush INCR burst on IDLE ---
        // When no new address phase and no pending transfer, IDLE means burst ended
        if (!pending_valid && !(vif.monitor_cb.HTRANS inside {2'b10, 2'b11}) && in_burst) begin
            burst_ap.write(assemble_burst(beat_buffer));
            beat_buffer.delete();
            in_burst = 0;
        end
    end
endtask

// Assemble burst-level transaction from beat buffer
function ahb_transaction ahb_monitor::assemble_burst(ahb_transaction buffer[$]);
    ahb_transaction burst_txn;
    burst_txn = ahb_transaction::type_id::create("burst_txn");

    burst_txn.xact_type    = buffer[0].xact_type;
    burst_txn.addr         = buffer[0].addr;
    burst_txn.burst_type   = buffer[0].burst_type;
    burst_txn.burst_size   = buffer[0].burst_size;
    burst_txn.prot         = buffer[0].prot;
    burst_txn.burst_length = buffer.size();
    burst_txn.hresp        = buffer[buffer.size()-1].hresp;

    burst_txn.data = new[buffer.size()];
    foreach (buffer[i])
        burst_txn.data[i] = buffer[i].data[0];

    return burst_txn;
endfunction

// Check if burst is complete (fixed length)
function bit ahb_monitor::is_burst_complete(ahb_transaction txn);
    if (txn.burst_type == SINGLE) return 1;
    if (txn.burst_type inside {INCR4, INCR8, INCR16, WRAP4, WRAP8, WRAP16})
        return (txn.beat_num == txn.get_burst_length() - 1);
    return 0;  // INCR: wait for next NONSEQ/IDLE
endfunction

`endif // AHB_MONITOR_SV
