`ifndef APB_RANDOM_TEST_SV
`define APB_RANDOM_TEST_SV

class apb_random_test extends apb_base_test;
    `uvm_component_utils(apb_random_test)

    task run_phase(uvm_phase phase);
        apb_rw_seq rw_seq;

        phase.raise_objection(this);

        rw_seq = apb_rw_seq::type_id::create("rw_seq");
        rw_seq.num_txns = 50;
        rw_seq.start(apb_agt.sqr);

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // APB_RANDOM_TEST_SV
