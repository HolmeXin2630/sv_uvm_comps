// vip/amba/ahb/test/ahb_wait_state_test.sv
`ifndef AHB_WAIT_STATE_TEST_SV
`define AHB_WAIT_STATE_TEST_SV

class ahb_wait_state_test extends ahb_base_test;
    `uvm_component_utils(ahb_wait_state_test)

    function new(string name = "ahb_wait_state_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env_cfg.init_lite();
        env_cfg.slave_cfg[0].wait_cycles = 2;
        env.env_cfg = env_cfg;
    endfunction

    task run_phase(uvm_phase phase);
        ahb_single_write_seq wr_seq;
        ahb_single_read_seq  rd_seq;

        phase.raise_objection(this);

        wr_seq = ahb_single_write_seq::type_id::create("wr_seq");
        wr_seq.wr_addr = 'h300;
        wr_seq.wr_data = 'hCAFEBABE;
        wr_seq.start(env.master_agt[0].sqr);

        rd_seq = ahb_single_read_seq::type_id::create("rd_seq");
        rd_seq.rd_addr = 'h300;
        rd_seq.start(env.master_agt[0].sqr);

        if (rd_seq.rd_data !== 'hCAFEBABE)
            `uvm_error("WAIT", $sformatf("Read mismatch: expected=0xCAFEBABE, actual=0x%08h", rd_seq.rd_data))
        else
            `uvm_info("WAIT", "Wait state test PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // AHB_WAIT_STATE_TEST_SV
