// vip/amba/ahb/src/ahb_monitor.sv
`ifndef AHB_MONITOR_SV
`define AHB_MONITOR_SV

class ahb_monitor extends uvm_monitor;
    `uvm_component_utils(ahb_monitor)

    virtual ahb_interface.monitor vif;

    // Dual analysis ports
    uvm_analysis_port #(ahb_transaction) beat_ap;   // Per-beat (coverage, slave sequence)
    uvm_analysis_port #(ahb_transaction) burst_ap;  // Per-burst (scoreboard)

    // Burst context
    ahb_transaction beat_buffer[$];
    int unsigned beat_count;
    bit in_burst;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        beat_ap  = new("beat_ap", this);
        burst_ap = new("burst_ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        ahb_transaction txn;

        forever begin
            @(vif.monitor_cb);

            // Detect IDLE: flush previous INCR burst
            if (vif.monitor_cb.HTRANS == 2'b00 && vif.monitor_cb.HREADY && in_burst) begin
                burst_ap.write(assemble_burst(beat_buffer));
                beat_buffer.delete();
                in_burst = 0;
            end

            // Detect valid transfer: NONSEQ/SEQ + HREADY
            if (vif.monitor_cb.HTRANS inside {2'b10, 2'b11} && vif.monitor_cb.HREADY) begin
                txn = ahb_transaction::type_id::create("txn");

                // Sample signals
                txn.addr       = vif.monitor_cb.HADDR;
                txn.xact_type  = vif.monitor_cb.HWRITE ? WRITE : READ;
                txn.burst_type = hburst_e'(vif.monitor_cb.HBURST);
                txn.burst_size = hsize_e'(vif.monitor_cb.HSIZE);
                txn.prot       = vif.monitor_cb.HPROT;
                txn.hresp      = hresp_e'(vif.monitor_cb.HRESP);

                txn.is_first_beat = (vif.monitor_cb.HTRANS == 2'b10);  // NONSEQ

                // Sample data
                txn.data = new[1];
                if (txn.xact_type == WRITE)
                    txn.data[0] = vif.monitor_cb.HWDATA;
                else
                    txn.data[0] = vif.monitor_cb.HRDATA;

                // Update burst context
                if (txn.is_first_beat) begin
                    if (beat_buffer.size() > 0)
                        burst_ap.write(assemble_burst(beat_buffer));
                    beat_buffer.delete();
                    beat_count = 0;
                end else begin
                    beat_count++;
                end
                txn.beat_num     = beat_count;
                txn.burst_length = txn.get_burst_length();

                // Send beat
                beat_ap.write(txn);

                // Buffer for burst assembly
                beat_buffer.push_back(txn);
                in_burst = 1;

                // Check burst completion (fixed length)
                if (is_burst_complete(txn)) begin
                    burst_ap.write(assemble_burst(beat_buffer));
                    beat_buffer.delete();
                    in_burst = 0;
                end
            end
        end
    endtask

    // Assemble burst-level transaction
    function ahb_transaction assemble_burst(ahb_transaction buffer[$]);
        ahb_transaction burst_txn;
        burst_txn = ahb_transaction::type_id::create("burst_txn");

        burst_txn.xact_type   = buffer[0].xact_type;
        burst_txn.addr        = buffer[0].addr;
        burst_txn.burst_type  = buffer[0].burst_type;
        burst_txn.burst_size  = buffer[0].burst_size;
        burst_txn.prot        = buffer[0].prot;
        burst_txn.burst_length = buffer.size();
        burst_txn.hresp       = buffer[buffer.size()-1].hresp;

        burst_txn.data = new[buffer.size()];
        foreach (buffer[i])
            burst_txn.data[i] = buffer[i].data[0];

        return burst_txn;
    endfunction

    // Check if burst is complete (fixed length)
    function bit is_burst_complete(ahb_transaction txn);
        if (txn.burst_type == SINGLE) return 1;
        if (txn.burst_type inside {INCR4, INCR8, INCR16, WRAP4, WRAP8, WRAP16})
            return (txn.beat_num == txn.get_burst_length() - 1);
        return 0;  // INCR: wait for next NONSEQ/IDLE
    endfunction
endclass

`endif // AHB_MONITOR_SV
