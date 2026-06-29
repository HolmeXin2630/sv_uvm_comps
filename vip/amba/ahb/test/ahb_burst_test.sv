// vip/amba/ahb/test/ahb_burst_test.sv
`ifndef AHB_BURST_TEST_SV
`define AHB_BURST_TEST_SV

class ahb_burst_test extends ahb_base_test;
    `uvm_component_utils(ahb_burst_test)

    function new(string name = "ahb_burst_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env_cfg.init_lite();
        env.env_cfg = env_cfg;
    endfunction

    task run_phase(uvm_phase phase);
        ahb_burst_write_seq wr_seq;

        phase.raise_objection(this);

        // INCR4 burst write
        wr_seq = ahb_burst_write_seq::type_id::create("wr_seq");
        wr_seq.start_addr = 'h200;
        wr_seq.burst_type = INCR4;
        assert(wr_seq.randomize());
        wr_seq.start(env.master_agt[0].sqr);

        `uvm_info("BURST", "INCR4 burst write PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // AHB_BURST_TEST_SV
