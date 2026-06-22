`ifndef APB_TRANSACTION_SV
`define APB_TRANSACTION_SV

class apb_transaction extends uvm_sequence_item;
    `uvm_object_utils(apb_transaction)

    // Fields
    rand bit [`APB_ADDR_WIDTH-1:0] addr;
    rand bit [`APB_DATA_WIDTH-1:0] data;
    rand bit                       write;  // 1=write, 0=read
    rand int unsigned              idle_cycles;

`ifdef APB_APB4_ENABLE
    rand bit [`APB_DATA_WIDTH/8-1:0] strb;
    rand bit [2:0]                    prot;
`endif

    // Response fields (filled by driver/monitor)
    bit slverr;

    // Constraints
    constraint c_idle_cycles {
        idle_cycles inside {[0:5]};
    }

    `ifdef APB_APB4_ENABLE
    constraint c_strb_default {
        strb == {(`APB_DATA_WIDTH/8){1'b1}};
    }
    `endif

    // Constructor
    function new(string name = "apb_transaction");
        super.new(name);
    endfunction

    // Convert to string
    virtual function string convert2string();
        string s;
        s = $sformatf("addr=0x%08h data=0x%08h write=%0b idle=%0d",
                       addr, data, write, idle_cycles);
        `ifdef APB_APB4_ENABLE
        s = {s, $sformatf(" strb=0x%0h prot=%0b", strb, prot)};
        `endif
        if (slverr)
            s = {s, " SLVERR"};
        return s;
    endfunction

    // Compare method for scoreboard
    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        apb_transaction rhs_cast;
        if (!$cast(rhs_cast, rhs))
            return 0;

        // Compare all fields except response fields and metadata
        return (addr  == rhs_cast.addr) &&
               (data  == rhs_cast.data) &&
               (write == rhs_cast.write);
    endfunction

    // Copy method for clone operations
    virtual function void do_copy(uvm_object rhs);
        apb_transaction rhs_cast;
        super.do_copy(rhs);
        if (!$cast(rhs_cast, rhs))
            `uvm_fatal("COPY", "Type cast failed in do_copy")

        addr        = rhs_cast.addr;
        data        = rhs_cast.data;
        write       = rhs_cast.write;
        idle_cycles = rhs_cast.idle_cycles;
        slverr      = rhs_cast.slverr;
    `ifdef APB_APB4_ENABLE
        strb = rhs_cast.strb;
        prot = rhs_cast.prot;
    `endif
    endfunction

endclass

`endif // APB_TRANSACTION_SV
