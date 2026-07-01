// vip/amba/ahb/test/ahb_slave_test.sv
// Tests slave agent in passive mode monitoring DUT (ahb_slave_ram) responses.
`ifndef AHB_SLAVE_TEST_SV
`define AHB_SLAVE_TEST_SV

class ahb_slave_test extends ahb_base_test;
    `uvm_component_utils(ahb_slave_test)

    function new(string name = "ahb_slave_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env_cfg.init_lite();
        // Slave agent is passive (DUT drives responses)
        env.env_cfg = env_cfg;
    endfunction

    task run_phase(uvm_phase phase);
        ahb_single_write_seq wr_seq;
        ahb_single_read_seq  rd_seq;

        phase.raise_objection(this);

        // Write via master agent (DUT stores data)
        wr_seq = ahb_single_write_seq::type_id::create("wr_seq");
        wr_seq.wr_addr = 'h600;
        wr_seq.wr_data = 'hAABBCCDD;
        wr_seq.start(env.master_agt[0].sqr);

        // Read via master agent (DUT returns data)
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
