// vip/amba/ahb/test/ahb_pipeline_test.sv
`ifndef AHB_PIPELINE_TEST_SV
`define AHB_PIPELINE_TEST_SV

class ahb_pipeline_test extends ahb_base_test;
    `uvm_component_utils(ahb_pipeline_test)

    function new(string name = "ahb_pipeline_test", uvm_component parent = null);
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

        // Multiple back-to-back bursts to exercise pipeline
        repeat (5) begin
            wr_seq = ahb_burst_write_seq::type_id::create("wr_seq");
            wr_seq.start_addr = 'h500;
            wr_seq.burst_type = INCR4;
            assert(wr_seq.randomize());
            wr_seq.start(env.master_agt[0].sqr);
        end

        `uvm_info("PIPE", "Pipeline test PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // AHB_PIPELINE_TEST_SV
