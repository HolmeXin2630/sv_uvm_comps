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

endclass

`endif // APB_TRANSACTION_SV
