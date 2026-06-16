`ifndef APB_WAIT_STATE_TEST_SV
`define APB_WAIT_STATE_TEST_SV

class apb_wait_state_test extends apb_base_test;
    `uvm_component_utils(apb_wait_state_test)

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Note: DUT WAIT_CYCLES is set via Makefile parameter
    endfunction

    task run_phase(uvm_phase phase);
        apb_write_seq wr_seq;
        apb_read_seq  rd_seq;

        phase.raise_objection(this);

        wr_seq = apb_write_seq::type_id::create("wr_seq");
        wr_seq.addr = 'h200;
        wr_seq.data = 'hCAFEBABE;
        wr_seq.start(apb_agt.sqr);

        rd_seq = apb_read_seq::type_id::create("rd_seq");
        rd_seq.addr = 'h200;
        rd_seq.start(apb_agt.sqr);

        if (rd_seq.rdata !== 'hCAFEBABE)
            `uvm_error("WAIT", $sformatf("Read data mismatch: expected=0xCAFEBABE, actual=0x%08h", rd_seq.rdata))
        else
            `uvm_info("WAIT", "Wait state test PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // APB_WAIT_STATE_TEST_SV
