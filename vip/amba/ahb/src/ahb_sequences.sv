// vip/amba/ahb/src/ahb_sequences.sv
`ifndef AHB_SEQUENCES_SV
`define AHB_SEQUENCES_SV

// Single write sequence
class ahb_single_write_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_single_write_seq)

    bit [`AHB_ADDR_WIDTH-1:0] wr_addr;
    bit [`AHB_DATA_WIDTH-1:0] wr_data;

    function new(string name = "ahb_single_write_seq");
        super.new(name);
    endfunction

    task body();
        ahb_transaction txn;
        txn = ahb_transaction::type_id::create("txn");
        start_item(txn);
        assert(txn.randomize() with {
            txn.xact_type   == WRITE;
            txn.burst_type   == SINGLE;
            txn.is_first_beat == 1;
            txn.is_last_beat  == 1;
            txn.beat_num      == 0;
            txn.burst_length  == 1;
        }) else `uvm_fatal("RANDFAIL", "Randomize failed")
        txn.addr    = wr_addr;
        txn.data[0] = wr_data;
        finish_item(txn);
    endtask
endclass

// Single read sequence
class ahb_single_read_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_single_read_seq)

    bit [`AHB_ADDR_WIDTH-1:0] rd_addr;
    bit [`AHB_DATA_WIDTH-1:0] rd_data;

    function new(string name = "ahb_single_read_seq");
        super.new(name);
    endfunction

    task body();
        ahb_transaction txn;
        txn = ahb_transaction::type_id::create("txn");
        start_item(txn);
        assert(txn.randomize() with {
            txn.xact_type   == READ;
            txn.burst_type   == SINGLE;
            txn.is_first_beat == 1;
            txn.is_last_beat  == 1;
            txn.beat_num      == 0;
            txn.burst_length  == 1;
        }) else `uvm_fatal("RANDFAIL", "Randomize failed")
        txn.addr = rd_addr;
        finish_item(txn);
        rd_data = txn.data[0];
    endtask
endclass

// Burst write sequence
class ahb_burst_write_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_burst_write_seq)

    rand bit [`AHB_ADDR_WIDTH-1:0] start_addr;
    rand hburst_e                   burst_type;
    rand bit [`AHB_DATA_WIDTH-1:0]  burst_data[];

    function new(string name = "ahb_burst_write_seq");
        super.new(name);
    endfunction

    constraint c_burst {
        burst_type inside {INCR4, WRAP4, INCR8, WRAP8};
        burst_data.size() == get_burst_length_from_type(burst_type);
    }

    function int get_burst_length_from_type(hburst_e bt);
        case (bt)
            SINGLE: return 1;
            INCR4, WRAP4: return 4;
            INCR8, WRAP8: return 8;
            INCR16, WRAP16: return 16;
            default: return 4;
        endcase
    endfunction

    task body();
        ahb_transaction txn;
        int burst_len = burst_data.size();

        for (int i = 0; i < burst_len; i++) begin
            txn = ahb_transaction::type_id::create($sformatf("txn_%0d", i));
            start_item(txn);
            assert(txn.randomize() with {
                txn.xact_type     == WRITE;
                txn.addr          == local::start_addr;
                txn.burst_type    == local::burst_type;
                txn.burst_size    == WORD;
                txn.data[0]       == local::burst_data[i];
                txn.beat_num      == i;
                txn.burst_length  == local::burst_len;
                txn.is_first_beat == (i == 0);
                txn.is_last_beat  == (i == burst_len - 1);
            }) else `uvm_fatal("RANDFAIL", "Randomize failed")
            txn.addr = txn.get_beat_addr(i);
            finish_item(txn);
        end
    endtask
endclass

// Random read/write sequence
class ahb_random_rw_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_random_rw_seq)

    int unsigned num_txns = 10;

    function new(string name = "ahb_random_rw_seq");
        super.new(name);
    endfunction

    task body();
        ahb_transaction txn;
        repeat (num_txns) begin
            txn = ahb_transaction::type_id::create("txn");
            start_item(txn);
            assert(txn.randomize() with {
                txn.burst_type == SINGLE;
                txn.is_first_beat == 1;
                txn.is_last_beat  == 1;
                txn.beat_num      == 0;
                txn.burst_length  == 1;
            }) else `uvm_fatal("RANDFAIL", "Randomize failed")
            finish_item(txn);
        end
    endtask
endclass

// Slave response sequence
class ahb_slave_response_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_slave_response_seq)
    `uvm_declare_p_sequencer(ahb_slave_sequencer)

    bit [`AHB_DATA_WIDTH-1:0] mem [bit [`AHB_ADDR_WIDTH-1:0]];

    function new(string name = "ahb_slave_response_seq");
        super.new(name);
    endfunction

    task body();
        ahb_transaction req, rsp;
        forever begin
            p_sequencer.request_fifo.get(req);

            rsp = ahb_transaction::type_id::create("rsp");
            start_item(rsp);
            assert(rsp.randomize() with {
                rsp.xact_type   == req.xact_type;
                rsp.addr        == req.addr;
                rsp.burst_type  == req.burst_type;
                rsp.burst_size  == req.burst_size;
                rsp.hresp       == OKAY;
                rsp.wait_cycles == 0;
            }) else `uvm_fatal("RANDFAIL", "Randomize failed")

            if (req.xact_type == READ) begin
                rsp.data = new[1];
                rsp.data[0] = mem.exists(req.addr) ? mem[req.addr] : '0;
            end

            if (req.xact_type == WRITE)
                mem[req.addr] = req.data[0];

            finish_item(rsp);
        end
    endtask
endclass

`endif // AHB_SEQUENCES_SV
