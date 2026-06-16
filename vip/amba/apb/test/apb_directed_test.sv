`ifndef APB_DIRECTED_TEST_SV
`define APB_DIRECTED_TEST_SV

class apb_directed_test extends apb_base_test;
    `uvm_component_utils(apb_directed_test)

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Example: factory override could be done here
        // apb_driver::type_id::set_type_override(my_custom_driver::get_type());
    endfunction

    task run_phase(uvm_phase phase);
        apb_write_seq wr_seq;
        apb_read_seq  rd_seq;

        phase.raise_objection(this);

        // Directed writes to specific addresses
        for (int i = 0; i < 4; i++) begin
            wr_seq = apb_write_seq::type_id::create($sformatf("wr_%0d", i));
            wr_seq.addr = i * 'h4;
            wr_seq.data = i;
            wr_seq.start(apb_agt.sqr);
        end

        // Read back and verify
        for (int i = 0; i < 4; i++) begin
            rd_seq = apb_read_seq::type_id::create($sformatf("rd_%0d", i));
            rd_seq.addr = i * 'h4;
            rd_seq.start(apb_agt.sqr);

            if (rd_seq.rdata !== i)
                `uvm_error("DIR", $sformatf("Mismatch at 0x%08h: expected=%0d, actual=0x%08h", i*4, i, rd_seq.rdata))
        end

        `uvm_info("DIR", "Directed test PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // APB_DIRECTED_TEST_SV
