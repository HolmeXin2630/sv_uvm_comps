`ifndef APB_SMOKE_TEST_SV
`define APB_SMOKE_TEST_SV

class apb_smoke_test extends apb_base_test;
    `uvm_component_utils(apb_smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_write_seq wr_seq;
        apb_read_seq  rd_seq;

        phase.raise_objection(this);

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
            `uvm_error("SMOKE", $sformatf("Read data mismatch: expected=0xDEADBEEF, actual=0x%08h", rd_seq.rdata))
        else
            `uvm_info("SMOKE", "Write/Read test PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // APB_SMOKE_TEST_SV
