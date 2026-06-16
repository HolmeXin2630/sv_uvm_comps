`ifndef APB_SEQUENCES_SV
`define APB_SEQUENCES_SV

// Single write sequence
class apb_write_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_write_seq)

    rand bit [`APB_ADDR_WIDTH-1:0] addr;
    rand bit [`APB_DATA_WIDTH-1:0] data;

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

`endif // APB_SEQUENCES_SV
