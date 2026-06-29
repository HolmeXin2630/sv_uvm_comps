`ifndef APB_SEQUENCES_SV
`define APB_SEQUENCES_SV

// Single write sequence
class apb_write_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_write_seq)

    rand bit [`APB_ADDR_WIDTH-1:0] addr;
    rand bit [`APB_DATA_WIDTH-1:0] data;

    function new(string name = "apb_write_seq");
        super.new(name);
    endfunction

    task body();
        apb_transaction txn;
        txn = apb_transaction::type_id::create("txn");
        start_item(txn);
        assert(txn.randomize() with {
            txn.write == 1;
            txn.addr  == local::addr;
            txn.data  == local::data;
        }) else `uvm_fatal("RANDFAIL", "Randomize failed")
        finish_item(txn);
    endtask
endclass

// Single read sequence
class apb_read_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_read_seq)

    rand bit [`APB_ADDR_WIDTH-1:0] addr;
    bit [`APB_DATA_WIDTH-1:0] rdata;

    function new(string name = "apb_read_seq");
        super.new(name);
    endfunction

    task body();
        apb_transaction txn;
        txn = apb_transaction::type_id::create("txn");
        start_item(txn);
        assert(txn.randomize() with {
            txn.write == 0;
            txn.addr  == local::addr;
        }) else `uvm_fatal("RANDFAIL", "Randomize failed")
        finish_item(txn);
        rdata = txn.data;
    endtask
endclass

// Random read/write sequence
class apb_rw_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_rw_seq)

    int unsigned num_txns = 10;

    function new(string name = "apb_rw_seq");
        super.new(name);
    endfunction

    task body();
        apb_transaction txn;
        repeat (num_txns) begin
            txn = apb_transaction::type_id::create("txn");
            start_item(txn);
            assert(txn.randomize()) else `uvm_fatal("RANDFAIL", "Randomize failed")
            finish_item(txn);
        end
    endtask
endclass

// Slave response sequence
class apb_slave_response_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_slave_response_seq)

    bit [`APB_DATA_WIDTH-1:0] mem [bit [`APB_ADDR_WIDTH-1:0]];

    function new(string name = "apb_slave_response_seq");
        super.new(name);
    endfunction

    task body();
        apb_transaction req, rsp;
        forever begin
            // For slave mode: generate response
            rsp = apb_transaction::type_id::create("rsp");
            start_item(rsp);
            assert(rsp.randomize() with {
                rsp.slverr == 0;
            }) else `uvm_fatal("RANDFAIL", "Randomize failed")

            // Fill data for read
            if (!rsp.write)
                rsp.data = mem.exists(rsp.addr) ? mem[rsp.addr] : '0;

            finish_item(rsp);
        end
    endtask
endclass

`ifdef APB_APB4_ENABLE
// APB4 STRB walking sequence: exercises all strb patterns
class apb_apb4_strb_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_apb4_strb_seq)

    bit [`APB_ADDR_WIDTH-1:0] base_addr = 'h200;

    function new(string name = "apb_apb4_strb_seq");
        super.new(name);
    endfunction

    task body();
        apb_transaction txn;
        bit [`APB_DATA_WIDTH-1:0] expected;
        bit [3:0] strb_patterns[] = '{4'h1, 4'h2, 4'h4, 4'h8, 4'h3, 4'hC, 4'h5, 4'hA, 4'hF};

        // Phase 1: Write with each strb pattern
        foreach (strb_patterns[i]) begin
            bit [`APB_DATA_WIDTH-1:0] wdata;
            // Generate walking-ones data matching strb pattern
            for (int b = 0; b < 4; b++) begin
                wdata[b*8 +: 8] = strb_patterns[i][b] ? (8'h10 + i) : 8'h00;
            end

            txn = apb_transaction::type_id::create($sformatf("wr_strb_%0d", i));
            start_item(txn);
            assert(txn.randomize() with {
                txn.write == 1;
                txn.addr  == local::base_addr + i * 4;
                txn.data  == local::wdata;
                txn.strb  == local::strb_patterns[i];
            }) else `uvm_fatal("RANDFAIL", "Randomize failed")
            finish_item(txn);
        end

        // Phase 2: Read back and verify
        foreach (strb_patterns[i]) begin
            txn = apb_transaction::type_id::create($sformatf("rd_strb_%0d", i));
            start_item(txn);
            assert(txn.randomize() with {
                txn.write == 0;
                txn.addr  == local::base_addr + i * 4;
            }) else `uvm_fatal("RANDFAIL", "Randomize failed")
            finish_item(txn);
        end
    endtask
endclass

// APB4 partial write sequence: write full, then overwrite partial bytes
class apb_apb4_partial_write_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_apb4_partial_write_seq)

    bit [`APB_ADDR_WIDTH-1:0] base_addr = 'h300;

    function new(string name = "apb_apb4_partial_write_seq");
        super.new(name);
    endfunction

    task body();
        apb_transaction txn;

        // Step 1: Full word write 0xDEADBEEF
        txn = apb_transaction::type_id::create("wr_full");
        start_item(txn);
        assert(txn.randomize() with {
            txn.write == 1;
            txn.addr  == local::base_addr;
            txn.data  == 32'hDEADBEEF;
            txn.strb  == 4'hF;
        }) else `uvm_fatal("RANDFAIL", "Randomize failed")
        finish_item(txn);

        // Step 2: Partial write — overwrite only byte[0] and byte[2]
        txn = apb_transaction::type_id::create("wr_partial");
        start_item(txn);
        assert(txn.randomize() with {
            txn.write == 1;
            txn.addr  == local::base_addr;
            txn.data  == 32'h00CC00AA;
            txn.strb  == 4'h5;  // byte0 + byte2
        }) else `uvm_fatal("RANDFAIL", "Randomize failed")
        finish_item(txn);

        // Step 3: Read back — expected: DEADCCEF (byte1/byte3 unchanged)
        txn = apb_transaction::type_id::create("rd_partial");
        start_item(txn);
        assert(txn.randomize() with {
            txn.write == 0;
            txn.addr  == local::base_addr;
        }) else `uvm_fatal("RANDFAIL", "Randomize failed")
        finish_item(txn);
    endtask
endclass
`endif

`endif // APB_SEQUENCES_SV
