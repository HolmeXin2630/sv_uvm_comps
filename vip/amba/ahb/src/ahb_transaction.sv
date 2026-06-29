// vip/amba/ahb/src/ahb_transaction.sv
`ifndef AHB_TRANSACTION_SV
`define AHB_TRANSACTION_SV

// Enums
typedef enum bit       {READ = 0, WRITE = 1} xact_type_e;
typedef enum bit [2:0] {SINGLE = 3'b000, INCR = 3'b001, WRAP4 = 3'b010, INCR4 = 3'b011,
                        WRAP8 = 3'b100, INCR8 = 3'b101, WRAP16 = 3'b110, INCR16 = 3'b111} hburst_e;
typedef enum bit [2:0] {BYTE = 3'b000, HALFWORD = 3'b001, WORD = 3'b010,
                        DWORD_64 = 3'b011, DWORD_128 = 3'b100,
                        DWORD_256 = 3'b101, DWORD_512 = 3'b110, DWORD_1024 = 3'b111} hsize_e;
typedef enum bit [1:0] {OKAY = 2'b00, ERROR = 2'b01, RETRY = 2'b10, SPLIT = 2'b11} hresp_e;

class ahb_transaction extends uvm_sequence_item;
    `uvm_object_utils(ahb_transaction)

    // Fields
    rand xact_type_e                xact_type;
    rand bit [`AHB_ADDR_WIDTH-1:0]  addr;
    rand hburst_e                   burst_type;
    rand hsize_e                    burst_size;
    rand bit [`AHB_DATA_WIDTH-1:0]  data[];  // Beat-level: length 1 for driver/beat_ap
    rand bit [3:0]                  prot;
    rand int unsigned               wait_cycles;  // Slave 专用

    // Response fields
    hresp_e                         hresp;

    // Context fields
    rand int unsigned               beat_num;
    rand int unsigned               burst_length;
    rand bit                        is_first_beat;
    rand bit                        is_last_beat;

    // Constraints
    constraint c_data_size {
        data.size() == 1;  // Beat-level: single beat
    }

    constraint c_wait_cycles {
        wait_cycles inside {[0:5]};
    }

    constraint c_default {
        burst_size == WORD;
        prot == 4'b0011;
    }

    // Constructor
    function new(string name = "ahb_transaction");
        super.new(name);
    endfunction

    // Get transfer size in bytes
    function int get_transfer_size();
        return 2 ** burst_size;
    endfunction

    // Get burst length from burst type
    function int get_burst_length();
        case (burst_type)
            SINGLE:  return 1;
            INCR:    return 16;  // Max, actual determined by HTRANS
            INCR4:   return 4;
            INCR8:   return 8;
            INCR16:  return 16;
            WRAP4:   return 4;
            WRAP8:   return 8;
            WRAP16:  return 16;
            default: return 1;
        endcase
    endfunction

    // Get beat address (supports WRAP)
    function bit [`AHB_ADDR_WIDTH-1:0] get_beat_addr(int beat);
        int transfer_size = get_transfer_size();
        int burst_len = get_burst_length();
        bit [`AHB_ADDR_WIDTH-1:0] aligned_addr;
        int wrap_boundary;

        case (burst_type)
            WRAP4, WRAP8, WRAP16: begin
                wrap_boundary = burst_len * transfer_size;
                aligned_addr = (addr / wrap_boundary) * wrap_boundary;
                return aligned_addr + ((addr - aligned_addr + beat * transfer_size) % wrap_boundary);
            end
            default:
                return addr + beat * transfer_size;
        endcase
    endfunction

    // Convert to string
    virtual function string convert2string();
        return $sformatf("%s addr=0x%08h data=0x%08h burst=%s size=%s beat=%0d/%0d %s %s",
            xact_type.name(), addr, data[0], burst_type.name(), burst_size.name(),
            beat_num, burst_length, is_first_beat ? "FIRST" : "", is_last_beat ? "LAST" : "");
    endfunction
endclass

`endif // AHB_TRANSACTION_SV
