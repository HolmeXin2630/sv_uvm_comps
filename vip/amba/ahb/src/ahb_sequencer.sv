// vip/amba/ahb/src/ahb_sequencer.sv
`ifndef AHB_SEQUENCER_SV
`define AHB_SEQUENCER_SV

// Master Sequencer
class ahb_sequencer extends uvm_sequencer #(ahb_transaction);
    `uvm_component_utils(ahb_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

// Slave Sequencer (with request FIFO)
class ahb_slave_sequencer extends uvm_sequencer #(ahb_transaction);
    `uvm_component_utils(ahb_slave_sequencer)

    uvm_tlm_analysis_fifo #(ahb_transaction) request_fifo;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        request_fifo = new("request_fifo", this);
    endfunction
endclass

`endif // AHB_SEQUENCER_SV
