// vip/amba/ahb/test/ahb_error_resp_test.sv
`ifndef AHB_ERROR_RESP_TEST_SV
`define AHB_ERROR_RESP_TEST_SV

class ahb_error_resp_test extends ahb_base_test;
    `uvm_component_utils(ahb_error_resp_test)

    function new(string name = "ahb_error_resp_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env_cfg.init_lite();
        env.env_cfg = env_cfg;
    endfunction

    task run_phase(uvm_phase phase);
        ahb_single_write_seq wr_seq;

        phase.raise_objection(this);

        wr_seq = ahb_single_write_seq::type_id::create("wr_seq");
        wr_seq.wr_addr = 'h400;
        wr_seq.wr_data = 'h12345678;
        wr_seq.start(env.master_agt[0].sqr);

        `uvm_info("ERR", "Error response test completed", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // AHB_ERROR_RESP_TEST_SV
