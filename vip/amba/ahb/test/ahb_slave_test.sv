// vip/amba/ahb/test/ahb_slave_test.sv
`ifndef AHB_SLAVE_TEST_SV
`define AHB_SLAVE_TEST_SV

class ahb_slave_test extends ahb_base_test;
    `uvm_component_utils(ahb_slave_test)

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env_cfg.init_lite();
        env.env_cfg = env_cfg;
    endfunction

    task run_phase(uvm_phase phase);
        ahb_single_write_seq wr_seq;
        ahb_single_read_seq  rd_seq;
        ahb_slave_response_seq slv_seq;

        phase.raise_objection(this);

        // Start slave response sequence
        fork
            slv_seq = ahb_slave_response_seq::type_id::create("slv_seq");
            slv_seq.start(env.slave_agt[0].sqr);
        join_none

        // Write
        wr_seq = ahb_single_write_seq::type_id::create("wr_seq");
        wr_seq.wr_addr = 'h600;
        wr_seq.wr_data = 'hAABBCCDD;
        wr_seq.start(env.master_agt[0].sqr);

        // Read
        rd_seq = ahb_single_read_seq::type_id::create("rd_seq");
        rd_seq.rd_addr = 'h600;
        rd_seq.start(env.master_agt[0].sqr);

        if (rd_seq.rd_data !== 'hAABBCCDD)
            `uvm_error("SLV", $sformatf("Read mismatch: expected=0xAABBCCDD, actual=0x%08h", rd_seq.rd_data))
        else
            `uvm_info("SLV", "Slave agent test PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // AHB_SLAVE_TEST_SV
