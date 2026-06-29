`ifndef APB_APB4_TEST_SV
`define APB_APB4_TEST_SV

`ifdef APB_APB4_ENABLE
class apb_apb4_test extends apb_base_test;
    `uvm_component_utils(apb_apb4_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_apb4_strb_seq        strb_seq;
        apb_apb4_partial_write_seq partial_seq;
        apb_rw_seq               rw_seq;

        phase.raise_objection(this);

        // ── Test 1: STRB walking pattern ──────────────────────
        `uvm_info("APB4", "=== Test 1: STRB walking pattern ===", UVM_LOW)
        strb_seq = apb_apb4_strb_seq::type_id::create("strb_seq");
        strb_seq.start(apb_agt.sqr);

        // Read back strb-written addresses and verify byte-lane correctness
        begin
            bit [`APB_ADDR_WIDTH-1:0] base = 'h200;
            bit [3:0] strb_patterns[] = '{4'h1, 4'h2, 4'h4, 4'h8, 4'h3, 4'hC, 4'h5, 4'hA, 4'hF};

            foreach (strb_patterns[i]) begin
                apb_read_seq rd;
                bit [`APB_DATA_WIDTH-1:0] expected_data;

                // Build expected: only strb-enabled bytes have valid data
                for (int b = 0; b < 4; b++) begin
                    expected_data[b*8 +: 8] = strb_patterns[i][b] ? (8'h10 + i) : 8'h00;
                end

                rd = apb_read_seq::type_id::create($sformatf("verify_%0d", i));
                rd.addr = base + i * 4;
                rd.start(apb_agt.sqr);

                if (rd.rdata !== expected_data)
                    `uvm_error("APB4", $sformatf("STRB=0x%h mismatch at addr=0x%08h: expected=0x%08h, actual=0x%08h",
                        strb_patterns[i], base + i*4, expected_data, rd.rdata))
                else
                    `uvm_info("APB4", $sformatf("STRB=0x%h PASS at addr=0x%08h data=0x%08h",
                        strb_patterns[i], base + i*4, rd.rdata), UVM_MEDIUM)
            end
        end

        // ── Test 2: Partial write (overwrite subset of bytes) ──
        `uvm_info("APB4", "=== Test 2: Partial write ===", UVM_LOW)
        partial_seq = apb_apb4_partial_write_seq::type_id::create("partial_seq");
        partial_seq.start(apb_agt.sqr);

        // Read back and verify: DECCBEAA (byte1/byte3 from first write, byte0/byte2 from second)
        //   First write:  0xDEADBEEF, strb=0xF → all bytes
        //   Second write: 0x00CC00AA, strb=0x5 → byte0=0xAA, byte2=0xCC
        //   Expected:     byte0=0xAA, byte1=0xBE, byte2=0xCC, byte3=0xDE → 0xDECCBEAA
        begin
            apb_read_seq rd;
            rd = apb_read_seq::type_id::create("verify_partial");
            rd.addr = 'h300;
            rd.start(apb_agt.sqr);

            if (rd.rdata !== 32'hDECCBEAA)
                `uvm_error("APB4", $sformatf("Partial write mismatch: expected=0xDECCBEAA, actual=0x%08h", rd.rdata))
            else
                `uvm_info("APB4", $sformatf("Partial write PASS: data=0x%08h", rd.rdata), UVM_LOW)
        end

        // ── Test 3: Random APB4 transactions (prot + strb coverage) ──
        `uvm_info("APB4", "=== Test 3: Random APB4 transactions ===", UVM_LOW)
        rw_seq = apb_rw_seq::type_id::create("rw_seq");
        rw_seq.num_txns = 50;
        rw_seq.start(apb_agt.sqr);

        `uvm_info("APB4", "=== APB4 test completed ===", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass
`endif

`endif // APB_APB4_TEST_SV
