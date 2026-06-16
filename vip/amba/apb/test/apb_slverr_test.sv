`ifndef APB_SLVERR_TEST_SV
`define APB_SLVERR_TEST_SV

class apb_slverr_test extends apb_base_test;
    `uvm_component_utils(apb_slverr_test)

    task run_phase(uvm_phase phase);
        apb_write_seq wr_seq;

        phase.raise_objection(this);

        wr_seq = apb_write_seq::type_id::create("wr_seq");
        wr_seq.addr = 'h300;
        wr_seq.data = 'h12345678;
        wr_seq.start(apb_agt.sqr);

        // Monitor should report slverr=1
        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // APB_SLVERR_TEST_SV
