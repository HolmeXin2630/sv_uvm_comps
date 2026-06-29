// vip/amba/ahb/src/ahb_scoreboard.sv
`ifndef AHB_SCOREBOARD_SV
`define AHB_SCOREBOARD_SV

// Declare analysis imp variants at file/package scope
`uvm_analysis_imp_decl(_master)
`uvm_analysis_imp_decl(_slave)

class ahb_scoreboard extends uvm_component;
    `uvm_component_utils(ahb_scoreboard)

    uvm_analysis_imp_master #(ahb_transaction, ahb_scoreboard) master_export;
    uvm_analysis_imp_slave #(ahb_transaction, ahb_scoreboard) slave_export;

    ahb_transaction master_bursts[$];

    int unsigned match_count = 0;
    int unsigned mismatch_count = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        master_export = new("master_export", this);
        slave_export  = new("slave_export", this);
    endfunction

    function void write_master(ahb_transaction t);
        master_bursts.push_back(t);
    endfunction

    function void write_slave(ahb_transaction t);
        ahb_transaction master_txn;

        if (master_bursts.size() == 0) begin
            `uvm_error("SCB", "No master burst available for comparison")
            return;
        end
        master_txn = master_bursts.pop_front();
        compare_bursts(master_txn, t);
    endfunction

    function void compare_bursts(ahb_transaction m, ahb_transaction s);
        bit ok = 1;

        if (m.burst_type != s.burst_type) begin
            `uvm_error("SCB", $sformatf("Burst type mismatch: master=%s, slave=%s",
                m.burst_type.name(), s.burst_type.name()))
            ok = 0;
        end

        if (m.addr != s.addr) begin
            `uvm_error("SCB", $sformatf("Address mismatch: master=0x%08h, slave=0x%08h",
                m.addr, s.addr))
            ok = 0;
        end

        if (m.data.size() != s.data.size()) begin
            `uvm_error("SCB", $sformatf("Data size mismatch: master=%0d, slave=%0d",
                m.data.size(), s.data.size()))
            ok = 0;
        end else begin
            foreach (m.data[i]) begin
                if (m.data[i] !== s.data[i]) begin
                    `uvm_error("SCB", $sformatf("Data[%0d] mismatch: master=0x%08h, slave=0x%08h",
                        i, m.data[i], s.data[i]))
                    ok = 0;
                end
            end
        end

        if (ok) match_count++;
        else mismatch_count++;
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCB", $sformatf("Burst matches=%0d, mismatches=%0d", match_count, mismatch_count), UVM_LOW)
    endfunction
endclass

`endif // AHB_SCOREBOARD_SV
