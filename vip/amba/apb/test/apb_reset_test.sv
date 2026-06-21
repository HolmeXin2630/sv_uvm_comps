`ifndef APB_RESET_TEST_SV
`define APB_RESET_TEST_SV

class apb_reset_test extends apb_base_test;
    `uvm_component_utils(apb_reset_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_write_seq wr_seq;
        apb_read_seq  rd_seq;

        phase.raise_objection(this);

        // Wait for reset release
        `uvm_info("RESET", "Waiting for reset release...", UVM_MEDIUM)
        @(posedge apb_agt.cfg.vif.PRESETn);
        `uvm_info("RESET", "Reset released", UVM_MEDIUM)

        // Write to address 0x0000_0100
        wr_seq = apb_write_seq::type_id::create("wr_seq");
        wr_seq.addr = 'h100;
        wr_seq.data = 'hDEADBEEF;
        wr_seq.start(apb_agt.sqr);

        // Read from address 0x0000_0100
        rd_seq = apb_read_seq::type_id::create("rd_seq");
        rd_seq.addr = 'h100;
        rd_seq.start(apb_agt.sqr);

        // Verify read data
        if (rd_seq.rdata !== 'hDEADBEEF)
            `uvm_error("RESET", $sformatf("Read data mismatch: expected=0xDEADBEEF, actual=0x%08h", rd_seq.rdata))
        else
            `uvm_info("RESET", "Write/Read test PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // APB_RESET_TEST_SV
