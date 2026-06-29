// vip/amba/ahb/test/ahb_lite_test.sv
`ifndef AHB_LITE_TEST_SV
`define AHB_LITE_TEST_SV

class ahb_lite_test extends ahb_base_test;
    `uvm_component_utils(ahb_lite_test)

    function new(string name = "ahb_lite_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env_cfg.init_lite();
        env.env_cfg = env_cfg;
    endfunction

    task run_phase(uvm_phase phase);
        ahb_single_write_seq wr_seq;
        ahb_single_read_seq  rd_seq;

        phase.raise_objection(this);

        // Write
        wr_seq = ahb_single_write_seq::type_id::create("wr_seq");
        wr_seq.wr_addr = 'h100;
        wr_seq.wr_data = 'hDEADBEEF;
        wr_seq.start(env.master_agt[0].sqr);

        // Read
        rd_seq = ahb_single_read_seq::type_id::create("rd_seq");
        rd_seq.rd_addr = 'h100;
        rd_seq.start(env.master_agt[0].sqr);

        if (rd_seq.rd_data !== 'hDEADBEEF)
            `uvm_error("LITE", $sformatf("Read mismatch: expected=0xDEADBEEF, actual=0x%08h", rd_seq.rd_data))
        else
            `uvm_info("LITE", "AHB-Lite single write/read PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // AHB_LITE_TEST_SV
