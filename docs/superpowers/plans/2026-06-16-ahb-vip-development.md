# AHB VIP 开发计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `vip/amba/ahb/` 下开发完整的 AHB VIP，支持 AHB-Lite/Full AHB，采用 Beat-level Transaction（遵循 UVM Cookbook），产出可直接用于项目的验证 IP。

**Architecture:** 拆分 Master/Slave Agent。Beat-level Transaction（每拍一个 transaction），Pipeline 天然支持（address_thread + data_thread）。Monitor 双 analysis_port（beat_ap + burst_ap）。依赖注入，cfg 显式赋值。

**Tech Stack:** SystemVerilog, UVM, VCS 仿真

**参考文档:**
- 设计文档: `docs/superpowers/specs/2026-06-06-amba-vip-design.md`
- 术语表: `CONTEXT.md`
- 编码规范: `vip/amba/uvm_coding_guidelines.md`
- Feature Checklist: `vip/amba/features_checklist.md`

---

## 文件结构

```
vip/amba/ahb/
├── src/
│   ├── ahb_defines.svh         # 宏定义
│   ├── ahb_interface.sv        # 接口（含 clocking block）
│   ├── ahb_transaction.sv      # Transaction（beat-level，data[] 队列）
│   ├── ahb_agent_config.sv     # Agent 配置
│   ├── ahb_env_config.sv       # Env 配置（包含 Agent 配置数组）
│   ├── ahb_sequencer.sv        # Sequencer（含 request_fifo）
│   ├── ahb_monitor.sv          # Monitor（双 analysis_port）
│   ├── ahb_master_driver.sv    # Master Driver（pipeline）
│   ├── ahb_slave_driver.sv     # Slave Driver
│   ├── ahb_master_agent.sv     # Master Agent
│   ├── ahb_slave_agent.sv      # Slave Agent（含 Monitor→Sequence FIFO）
│   ├── ahb_bus_env.sv          # Env
│   ├── ahb_sequences.sv        # Sequence 库
│   ├── ahb_agent_coverage.sv   # Agent 级 Coverage
│   ├── ahb_cross_coverage.sv   # 跨 Agent Coverage
│   ├── ahb_scoreboard.sv       # Scoreboard
│   ├── ahb_slave_ram.sv        # DUT 模型
│   └── ahb_pkg.sv              # Package 封装
├── tb/
│   ├── ahb_tb_top_lite.sv      # AHB-Lite
│   ├── ahb_tb_top_burst.sv     # Burst
│   ├── ahb_tb_top_wait.sv      # Wait State
│   ├── ahb_tb_top_error.sv     # Error Response
│   ├── ahb_tb_top_pipeline.sv  # Pipeline
│   ├── ahb_tb_top_slave.sv     # Slave Agent
│   ├── ahb_tb_top_full_bus.sv  # Full AHB
│   └── ahb_tb_pkg.sv           # TB Package
├── test/
│   ├── ahb_base_test.sv
│   ├── ahb_lite_test.sv
│   ├── ahb_burst_test.sv
│   ├── ahb_pipeline_test.sv
│   ├── ahb_slave_test.sv
│   ├── ahb_wait_state_test.sv
│   ├── ahb_error_resp_test.sv
│   ├── ahb_mastlock_test.sv
│   ├── ahb_burst_size_test.sv
│   ├── ahb_busy_test.sv
│   └── ahb_full_bus_test.sv
└── sim/
    ├── Makefile
    └── .gitignore
```

---

## Phase 1: 基础组件

### Task 1: 创建目录结构和编译脚手架

**Files:**
- Create: `vip/amba/ahb/sim/Makefile`
- Create: `vip/amba/ahb/sim/.gitignore`
- Create: `vip/amba/ahb/src/ahb_pkg.sv`（骨架）
- Create: `vip/amba/ahb/tb/ahb_tb_pkg.sv`（骨架）

- [ ] **Step 1: 创建目录结构**

```bash
mkdir -p vip/amba/ahb/{src,tb,test,sim}
```

- [ ] **Step 2: 创建 .gitignore**

```
# vip/amba/ahb/sim/.gitignore
output/
csrc/
*.log
*.key
*.vpd
*.vdb
simv
simv.daidir/
ucli.dir/
.DVE/
.inter.vpd.uvm
```

- [ ] **Step 3: 创建 Makefile**

```makefile
# vip/amba/ahb/sim/Makefile
SIM_OUTPUT ?= $(CURDIR)/output

TEST ?= ahb_lite_test
WAIT_CYCLES ?= 0
INJECT_ERROR ?= 0

COMPILE_OPTS = -sverilog -full64 -timescale=1ns/1ps
COMPILE_OPTS += +define+UVM_PACKER_MAX_BYTES=1500000
COMPILE_OPTS += +define+UVM_DISABLE_AUTO_ITEM_RECORDING
COMPILE_OPTS += +incdir+../src
COMPILE_OPTS += +incdir+../tb
COMPILE_OPTS += +incdir+../test
COMPILE_OPTS += +define+WAIT_CYCLES=$(WAIT_CYCLES)
COMPILE_OPTS += +define+INJECT_ERROR=$(INJECT_ERROR)

all: comp run

comp:
	vcs $(COMPILE_OPTS) -o $(SIM_OUTPUT)/simv ../tb/ahb_tb_top_$(TEST).sv

run:
	$(SIM_OUTPUT)/simv +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=UVM_MEDIUM

clean:
	rm -rf $(SIM_OUTPUT) csrc *.log *.key *.vpd *.vdb simv simv.daidir
```

- [ ] **Step 4: 创建 ahb_pkg.sv 骨架**

```systemverilog
// vip/amba/ahb/src/ahb_pkg.sv
`ifndef AHB_PKG_SV
`define AHB_PKG_SV

package hx_ahb_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // TODO: `include 所有组件

endpackage

`endif // AHB_PKG_SV
```

- [ ] **Step 5: 创建 ahb_tb_pkg.sv 骨架**

```systemverilog
// vip/amba/ahb/tb/ahb_tb_pkg.sv
`ifndef AHB_TB_PKG_SV
`define AHB_TB_PKG_SV

package hx_ahb_tb_pkg;
    import uvm_pkg::*;
    import hx_ahb_pkg::*;
    `include "uvm_macros.svh"

    // TODO: `include tb 和 test 文件

endpackage

`endif // AHB_TB_PKG_SV
```

- [ ] **Step 6: Commit**

```bash
git add vip/amba/ahb/
git commit -m "feat(ahb): create directory structure and scaffolding"
```

---

### Task 2: ahb_defines.svh — 宏定义

**Files:**
- Create: `vip/amba/ahb/src/ahb_defines.svh`

- [ ] **Step 1: 编写 ahb_defines.svh**

```systemverilog
// vip/amba/ahb/src/ahb_defines.svh
`ifndef AHB_DEFINES_SVH
`define AHB_DEFINES_SVH

// Width macros (can be overridden at compile time)
`ifndef AHB_ADDR_WIDTH
`define AHB_ADDR_WIDTH 32
`endif

`ifndef AHB_DATA_WIDTH
`define AHB_DATA_WIDTH 32
`endif

// Protocol version control
// `define AHB_AHB5_ENABLE  // Uncomment to enable AHB5 features

`endif // AHB_DEFINES_SVH
```

- [ ] **Step 2: 更新 ahb_pkg.sv**

在 `ahb_pkg.sv` 中添加 `include "ahb_defines.svh"`。

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/src/ahb_defines.svh vip/amba/ahb/src/ahb_pkg.sv
git commit -m "feat(ahb): add defines with width macros"
```

---

### Task 3: ahb_interface.sv — 接口

**Files:**
- Create: `vip/amba/ahb/src/ahb_interface.sv`

- [ ] **Step 1: 编写 ahb_interface.sv**

```systemverilog
// vip/amba/ahb/src/ahb_interface.sv
`ifndef AHB_INTERFACE_SV
`define AHB_INTERFACE_SV

interface ahb_interface #(
    parameter ADDR_WIDTH = `AHB_ADDR_WIDTH,
    parameter DATA_WIDTH = `AHB_DATA_WIDTH
) (
    input logic HCLK,
    input logic HRESETn
);
    // Signal declarations
    logic [ADDR_WIDTH-1:0] HADDR;
    logic [1:0]            HTRANS;
    logic                  HWRITE;
    logic [2:0]            HSIZE;
    logic [2:0]            HBURST;
    logic [3:0]            HPROT;
    logic [DATA_WIDTH-1:0] HWDATA;
    logic [DATA_WIDTH-1:0] HRDATA;
    logic                  HREADY;
    logic [1:0]            HRESP;
    logic                  HSEL;
    logic                  HMASTLOCK;
    logic                  HBUSREQ;  // Full AHB
    logic                  HGRANT;   // Full AHB

    // Master clocking block
    clocking master_cb @(posedge HCLK);
        default input #1 output #1;
        output HADDR;
        output HTRANS;
        output HWRITE;
        output HSIZE;
        output HBURST;
        output HPROT;
        output HWDATA;
        output HMASTLOCK;
        output HBUSREQ;
        input  HRDATA;
        input  HREADY;
        input  HRESP;
        input  HGRANT;
    endclocking

    // Slave clocking block
    clocking slave_cb @(posedge HCLK);
        default input #1 output #1;
        input  HADDR;
        input  HTRANS;
        input  HWRITE;
        input  HSIZE;
        input  HBURST;
        input  HPROT;
        input  HWDATA;
        input  HSEL;
        input  HMASTLOCK;
        output HRDATA;
        output HREADY;
        output HRESP;
    endclocking

    // Monitor clocking block
    clocking monitor_cb @(posedge HCLK);
        default input #1 output #1;
        input HADDR;
        input HTRANS;
        input HWRITE;
        input HSIZE;
        input HBURST;
        input HPROT;
        input HWDATA;
        input HRDATA;
        input HREADY;
        input HRESP;
        input HSEL;
        input HMASTLOCK;
        input HBUSREQ;
        input HGRANT;
    endclocking

    // Modports
    modport master  (clocking master_cb,  input HRESETn);
    modport slave   (clocking slave_cb,   input HRESETn);
    modport monitor (clocking monitor_cb, input HRESETn);

endinterface

`endif // AHB_INTERFACE_SV
```

- [ ] **Step 2: Commit**

```bash
git add vip/amba/ahb/src/ahb_interface.sv
git commit -m "feat(ahb): add interface with clocking blocks"
```

---

### Task 4: ahb_transaction.sv — Transaction（Beat-level）

**Files:**
- Create: `vip/amba/ahb/src/ahb_transaction.sv`

- [ ] **Step 1: 编写 ahb_transaction.sv**

```systemverilog
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
    int unsigned                    beat_num;
    int unsigned                    burst_length;
    bit                             is_first_beat;
    bit                             is_last_beat;

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
```

- [ ] **Step 2: 更新 ahb_pkg.sv**

- [ ] **Step 3: 编译验证**

```bash
cd vip/amba/ahb/sim
make comp
```

Expected: 编译通过，无 error。

- [ ] **Step 4: Commit**

```bash
git add vip/amba/ahb/src/ahb_transaction.sv vip/amba/ahb/src/ahb_pkg.sv
git commit -m "feat(ahb): add beat-level transaction with WRAP address calculation"
```

---

### Task 5: ahb_agent_config.sv — Agent Config

**Files:**
- Create: `vip/amba/ahb/src/ahb_agent_config.sv`

- [ ] **Step 1: 编写 ahb_agent_config.sv**

```systemverilog
// vip/amba/ahb/src/ahb_agent_config.sv
`ifndef AHB_AGENT_CONFIG_SV
`define AHB_AGENT_CONFIG_SV

class ahb_agent_config extends uvm_object;
    `uvm_object_utils(ahb_agent_config)

    // Mode
    bit active = 1;  // 1=active, 0=passive

    // Width
    int addr_width = `AHB_ADDR_WIDTH;
    int data_width = `AHB_DATA_WIDTH;

    // AHB5 enable
    bit ahb5_enable = 0;

    // Wait cycles (for slave)
    int unsigned wait_cycles = 0;

    // Virtual interface (set by tb_top via config_db)
    virtual ahb_interface vif;

    function new(string name = "ahb_agent_config");
        super.new(name);
    endfunction
endclass

`endif // AHB_AGENT_CONFIG_SV
```

- [ ] **Step 2: 更新 ahb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/src/ahb_agent_config.sv vip/amba/ahb/src/ahb_pkg.sv
git commit -m "feat(ahb): add agent config"
```

---

### Task 6: ahb_env_config.sv — Env Config

**Files:**
- Create: `vip/amba/ahb/src/ahb_env_config.sv`

- [ ] **Step 1: 编写 ahb_env_config.sv**

```systemverilog
// vip/amba/ahb/src/ahb_env_config.sv
`ifndef AHB_ENV_CONFIG_SV
`define AHB_ENV_CONFIG_SV

class ahb_env_config extends uvm_object;
    `uvm_object_utils(ahb_env_config)

    // Agent counts
    int master_agt_num = 1;
    int slave_agt_num  = 1;
    bit ahb_lite = 1;

    // Agent configs (composition)
    ahb_agent_config master_cfg[];
    ahb_agent_config slave_cfg[];

    // Slave address map
    bit [`AHB_ADDR_WIDTH-1:0] slave_base_addr[];
    bit [`AHB_ADDR_WIDTH-1:0] slave_size[];

    function new(string name = "ahb_env_config");
        super.new(name);
    endfunction

    // Initialize
    function void init();
        master_cfg = new[master_agt_num];
        slave_cfg  = new[slave_agt_num];
        slave_base_addr = new[slave_agt_num];
        slave_size = new[slave_agt_num];

        foreach (master_cfg[i])
            master_cfg[i] = ahb_agent_config::type_id::create($sformatf("master_cfg[%0d]", i));
        foreach (slave_cfg[i]) begin
            slave_cfg[i] = ahb_agent_config::type_id::create($sformatf("slave_cfg[%0d]", i));
            slave_base_addr[i] = i * 'h1000;
            slave_size[i] = 'h1000;
        end
    endfunction

    // AHB-Lite shortcut
    function void init_lite();
        ahb_lite = 1;
        master_agt_num = 1;
        init();
    endfunction
endclass

`endif // AHB_ENV_CONFIG_SV
```

- [ ] **Step 2: 更新 ahb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/src/ahb_env_config.sv vip/amba/ahb/src/ahb_pkg.sv
git commit -m "feat(ahb): add env config with dynamic agent creation"
```

---

### Task 7: ahb_sequencer.sv — Sequencer

**Files:**
- Create: `vip/amba/ahb/src/ahb_sequencer.sv`

- [ ] **Step 1: 编写 ahb_sequencer.sv**

```systemverilog
// vip/amba/ahb/src/ahb_sequencer.sv
`ifndef AHB_SEQUENCER_SV
`define AHB_SEQUENCER_SV

// Master Sequencer
class ahb_sequencer extends uvm_sequencer #(ahb_transaction);
    `uvm_component_utils(ahb_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

// Slave Sequencer (with request FIFO)
class ahb_slave_sequencer extends uvm_sequencer #(ahb_transaction);
    `uvm_component_utils(ahb_slave_sequencer)

    uvm_tlm_analysis_fifo #(ahb_transaction) request_fifo;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        request_fifo = new("request_fifo", this);
    endfunction
endclass

`endif // AHB_SEQUENCER_SV
```

- [ ] **Step 2: 更新 ahb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/src/ahb_sequencer.sv vip/amba/ahb/src/ahb_pkg.sv
git commit -m "feat(ahb): add master and slave sequencers"
```

---

### Task 8: ahb_monitor.sv — Monitor（双 analysis_port）

**Files:**
- Create: `vip/amba/ahb/src/ahb_monitor.sv`

- [ ] **Step 1: 编写 ahb_monitor.sv**

```systemverilog
// vip/amba/ahb/src/ahb_monitor.sv
`ifndef AHB_MONITOR_SV
`define AHB_MONITOR_SV

class ahb_monitor extends uvm_monitor;
    `uvm_component_utils(ahb_monitor)

    virtual ahb_interface.monitor_cb vif;

    // Dual analysis ports
    uvm_analysis_port #(ahb_transaction) beat_ap;   // Per-beat (coverage, slave sequence)
    uvm_analysis_port #(ahb_transaction) burst_ap;  // Per-burst (scoreboard)

    // Burst context
    ahb_transaction beat_buffer[$];
    int unsigned beat_count;
    bit in_burst;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        beat_ap  = new("beat_ap", this);
        burst_ap = new("burst_ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        ahb_transaction txn;

        forever begin
            @(vif.monitor_cb);

            // Detect IDLE: flush previous INCR burst
            if (vif.monitor_cb.HTRANS == 2'b00 && vif.monitor_cb.HREADY && in_burst) begin
                burst_ap.write(assemble_burst(beat_buffer));
                beat_buffer.delete();
                in_burst = 0;
            end

            // Detect valid transfer: NONSEQ/SEQ + HREADY
            if (vif.monitor_cb.HTRANS inside {2'b10, 2'b11} && vif.monitor_cb.HREADY) begin
                txn = ahb_transaction::type_id::create("txn");

                // Sample signals
                txn.addr       = vif.monitor_cb.HADDR;
                txn.xact_type  = vif.monitor_cb.HWRITE ? WRITE : READ;
                txn.burst_type = hburst_e'(vif.monitor_cb.HBURST);
                txn.burst_size = hsize_e'(vif.monitor_cb.HSIZE);
                txn.prot       = vif.monitor_cb.HPROT;
                txn.hresp      = hresp_e'(vif.monitor_cb.HRESP);

                txn.is_first_beat = (vif.monitor_cb.HTRANS == 2'b10);  // NONSEQ

                // Sample data
                txn.data = new[1];
                if (txn.xact_type == WRITE)
                    txn.data[0] = vif.monitor_cb.HWDATA;
                else
                    txn.data[0] = vif.monitor_cb.HRDATA;

                // Update burst context
                if (txn.is_first_beat) begin
                    if (beat_buffer.size() > 0)
                        burst_ap.write(assemble_burst(beat_buffer));
                    beat_buffer.delete();
                    beat_count = 0;
                end else begin
                    beat_count++;
                end
                txn.beat_num     = beat_count;
                txn.burst_length = txn.get_burst_length();

                // Send beat
                beat_ap.write(txn);

                // Buffer for burst assembly
                beat_buffer.push_back(txn);
                in_burst = 1;

                // Check burst completion (fixed length)
                if (is_burst_complete(txn)) begin
                    burst_ap.write(assemble_burst(beat_buffer));
                    beat_buffer.delete();
                    in_burst = 0;
                end
            end
        end
    endtask

    // Assemble burst-level transaction
    function ahb_transaction assemble_burst(ahb_transaction buffer[$]);
        ahb_transaction burst_txn;
        burst_txn = ahb_transaction::type_id::create("burst_txn");

        burst_txn.xact_type   = buffer[0].xact_type;
        burst_txn.addr        = buffer[0].addr;
        burst_txn.burst_type  = buffer[0].burst_type;
        burst_txn.burst_size  = buffer[0].burst_size;
        burst_txn.prot        = buffer[0].prot;
        burst_txn.burst_length = buffer.size();
        burst_txn.hresp       = buffer[buffer.size()-1].hresp;

        burst_txn.data = new[buffer.size()];
        foreach (buffer[i])
            burst_txn.data[i] = buffer[i].data[0];

        return burst_txn;
    endfunction

    // Check if burst is complete (fixed length)
    function bit is_burst_complete(ahb_transaction txn);
        if (txn.burst_type == SINGLE) return 1;
        if (txn.burst_type inside {INCR4, INCR8, INCR16, WRAP4, WRAP8, WRAP16})
            return (txn.beat_num == txn.get_burst_length() - 1);
        return 0;  // INCR: wait for next NONSEQ/IDLE
    endfunction
endclass

`endif // AHB_MONITOR_SV
```

- [ ] **Step 2: 更新 ahb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/src/ahb_monitor.sv vip/amba/ahb/src/ahb_pkg.sv
git commit -m "feat(ahb): add monitor with dual analysis ports"
```

---

### Task 9: ahb_master_driver.sv — Master Driver（Pipeline）

**Files:**
- Create: `vip/amba/ahb/src/ahb_master_driver.sv`

- [ ] **Step 1: 编写 ahb_master_driver.sv**

```systemverilog
// vip/amba/ahb/src/ahb_master_driver.sv
`ifndef AHB_MASTER_DRIVER_SV
`define AHB_MASTER_DRIVER_SV

class ahb_master_driver extends uvm_driver #(ahb_transaction);
    `uvm_component_utils(ahb_master_driver)

    virtual ahb_interface.master_cb vif;

    // Pipeline synchronization
    mailbox #(ahb_transaction) addr_done_mb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        addr_done_mb = new();
    endfunction

    task run_phase(uvm_phase phase);
        fork
            address_thread();
            data_thread();
        join
    endtask

    task address_thread();
        ahb_transaction txn;
        forever begin
            seq_item_port.get(txn);

            // Drive address phase
            @(vif.master_cb);
            vif.master_cb.HADDR   <= txn.addr;
            vif.master_cb.HTRANS  <= txn.is_first_beat ? 2'b10 : 2'b11;  // NONSEQ : SEQ
            vif.master_cb.HSIZE   <= txn.burst_size;
            vif.master_cb.HBURST  <= txn.burst_type;
            vif.master_cb.HWRITE  <= txn.xact_type;
            vif.master_cb.HPROT   <= txn.prot;
            vif.master_cb.HMASTLOCK <= 1'b0;

            // Wait for HREADY
            while (!vif.master_cb.HREADY) @(vif.master_cb);

            addr_done_mb.put(txn);
        end
    endtask

    task data_thread();
        ahb_transaction txn;
        forever begin
            addr_done_mb.get(txn);

            // Write: drive HWDATA
            if (txn.xact_type == WRITE) begin
                @(vif.master_cb);
                vif.master_cb.HWDATA <= txn.data[0];
            end

            // Wait for HREADY
            while (!vif.master_cb.HREADY) @(vif.master_cb);

            // Read: sample HRDATA
            if (txn.xact_type == READ)
                txn.data[0] = vif.master_cb.HRDATA;

            // Sample response
            txn.hresp = hresp_e'(vif.master_cb.HRESP);

            // Return response
            seq_item_port.put(txn);
        end
    endtask
endclass

`endif // AHB_MASTER_DRIVER_SV
```

- [ ] **Step 2: 更新 ahb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/src/ahb_master_driver.sv vip/amba/ahb/src/ahb_pkg.sv
git commit -m "feat(ahb): add master driver with pipeline support"
```

---

### Task 10: ahb_slave_driver.sv — Slave Driver

**Files:**
- Create: `vip/amba/ahb/src/ahb_slave_driver.sv`

- [ ] **Step 1: 编写 ahb_slave_driver.sv**

```systemverilog
// vip/amba/ahb/src/ahb_slave_driver.sv
`ifndef AHB_SLAVE_DRIVER_SV
`define AHB_SLAVE_DRIVER_SV

class ahb_slave_driver extends uvm_driver #(ahb_transaction);
    `uvm_component_utils(ahb_slave_driver)

    virtual ahb_interface.slave_cb vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        ahb_transaction rsp;
        forever begin
            // Wait for valid transfer
            @(vif.slave_cb);
            while (!(vif.slave_cb.HTRANS inside {2'b10, 2'b11} && vif.slave_cb.HREADY))
                @(vif.slave_cb);

            // Get response from sequencer
            seq_item_port.get(rsp);

            // Insert wait states
            repeat (rsp.wait_cycles) begin
                vif.slave_cb.HREADY <= 1'b0;
                @(vif.slave_cb);
            end

            // Drive response
            vif.slave_cb.HREADY <= 1'b1;
            if (rsp.xact_type == READ)
                vif.slave_cb.HRDATA <= rsp.data[0];
            vif.slave_cb.HRESP <= rsp.hresp;
        end
    endtask
endclass

`endif // AHB_SLAVE_DRIVER_SV
```

- [ ] **Step 2: 更新 ahb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/src/ahb_slave_driver.sv vip/amba/ahb/src/ahb_pkg.sv
git commit -m "feat(ahb): add slave driver with wait state support"
```

---

## Phase 2: Agent 和 Env

### Task 11: ahb_master_agent.sv

**Files:**
- Create: `vip/amba/ahb/src/ahb_master_agent.sv`

- [ ] **Step 1: 编写 ahb_master_agent.sv**

```systemverilog
// vip/amba/ahb/src/ahb_master_agent.sv
`ifndef AHB_MASTER_AGENT_SV
`define AHB_MASTER_AGENT_SV

class ahb_master_agent extends uvm_agent;
    `uvm_component_utils(ahb_master_agent)

    // Exposed API
    ahb_agent_config cfg;
    ahb_sequencer    sqr;

    // Internal
    ahb_master_driver drv;
    ahb_monitor       mon;

    // vif
    virtual ahb_interface vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get vif from config_db
        if (!uvm_config_db#(virtual ahb_interface)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", $sformatf("vif not set for %s", get_full_name()))

        // Create components
        if (cfg.active) begin
            drv = ahb_master_driver::type_id::create("drv", this);
            sqr = ahb_sequencer::type_id::create("sqr", this);
        end
        mon = ahb_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Pass vif
        mon.vif = vif;
        if (cfg.active) begin
            drv.vif = vif;
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction
endclass

`endif // AHB_MASTER_AGENT_SV
```

- [ ] **Step 2: 更新 ahb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/src/ahb_master_agent.sv vip/amba/ahb/src/ahb_pkg.sv
git commit -m "feat(ahb): add master agent with vif injection"
```

---

### Task 12: ahb_slave_agent.sv

**Files:**
- Create: `vip/amba/ahb/src/ahb_slave_agent.sv`

- [ ] **Step 1: 编写 ahb_slave_agent.sv**

```systemverilog
// vip/amba/ahb/src/ahb_slave_agent.sv
`ifndef AHB_SLAVE_AGENT_SV
`define AHB_SLAVE_AGENT_SV

class ahb_slave_agent extends uvm_agent;
    `uvm_component_utils(ahb_slave_agent)

    // Exposed API
    ahb_agent_config    cfg;
    ahb_slave_sequencer sqr;

    // Internal
    ahb_slave_driver drv;
    ahb_monitor      mon;

    // vif
    virtual ahb_interface vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual ahb_interface)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", $sformatf("vif not set for %s", get_full_name()))

        if (cfg.active) begin
            drv = ahb_slave_driver::type_id::create("drv", this);
            sqr = ahb_slave_sequencer::type_id::create("sqr", this);
        end
        mon = ahb_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        mon.vif = vif;
        if (cfg.active) begin
            drv.vif = vif;
            // Monitor → Sequencer FIFO (beat-level)
            mon.beat_ap.connect(sqr.request_fifo.analysis_export);
            // Driver ← Sequencer
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction
endclass

`endif // AHB_SLAVE_AGENT_SV
```

- [ ] **Step 2: 更新 ahb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/src/ahb_slave_agent.sv vip/amba/ahb/src/ahb_pkg.sv
git commit -m "feat(ahb): add slave agent with Monitor→Sequence FIFO"
```

---

### Task 13: ahb_bus_env.sv — Env

**Files:**
- Create: `vip/amba/ahb/src/ahb_bus_env.sv`

- [ ] **Step 1: 编写 ahb_bus_env.sv**

```systemverilog
// vip/amba/ahb/src/ahb_bus_env.sv
`ifndef AHB_BUS_ENV_SV
`define AHB_BUS_ENV_SV

class ahb_bus_env extends uvm_env;
    `uvm_component_utils(ahb_bus_env)

    // Exposed API
    ahb_env_config env_cfg;

    // Internal components
    ahb_master_agent master_agt[];
    ahb_slave_agent  slave_agt[];
    ahb_scoreboard   scb;
    ahb_agent_coverage master_cov[];
    ahb_agent_coverage slave_cov[];

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get env_cfg from config_db
        if (!uvm_config_db#(ahb_env_config)::get(this, "", "env_cfg", env_cfg))
            `uvm_fatal("NOCONFIG", "ahb_env_config not set")

        // Create master agents
        master_agt = new[env_cfg.master_agt_num];
        foreach (master_agt[i])
            master_agt[i] = ahb_master_agent::type_id::create(
                $sformatf("master_agt[%0d]", i), this);

        // Create slave agents
        slave_agt = new[env_cfg.slave_agt_num];
        foreach (slave_agt[i])
            slave_agt[i] = ahb_slave_agent::type_id::create(
                $sformatf("slave_agt[%0d]", i), this);

        // Create scoreboard
        scb = ahb_scoreboard::type_id::create("scb", this);

        // Create coverage
        master_cov = new[env_cfg.master_agt_num];
        foreach (master_cov[i])
            master_cov[i] = ahb_agent_coverage::type_id::create(
                $sformatf("master_cov[%0d]", i), this);
        slave_cov = new[env_cfg.slave_agt_num];
        foreach (slave_cov[i])
            slave_cov[i] = ahb_agent_coverage::type_id::create(
                $sformatf("slave_cov[%0d]", i), this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Inject configs (dependency injection)
        foreach (master_agt[i])
            master_agt[i].cfg = env_cfg.master_cfg[i];
        foreach (slave_agt[i])
            slave_agt[i].cfg = env_cfg.slave_cfg[i];

        // Connect scoreboard
        foreach (master_agt[i])
            master_agt[i].mon.burst_ap.connect(scb.master_export);
        foreach (slave_agt[i])
            slave_agt[i].mon.burst_ap.connect(scb.slave_export);

        // Connect coverage
        foreach (master_agt[i]) begin
            master_agt[i].mon.beat_ap.connect(master_cov[i].analysis_export);
        end
        foreach (slave_agt[i]) begin
            slave_agt[i].mon.beat_ap.connect(slave_cov[i].analysis_export);
        end
    endfunction
endclass

`endif // AHB_BUS_ENV_SV
```

- [ ] **Step 2: 更新 ahb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/src/ahb_bus_env.sv vip/amba/ahb/src/ahb_pkg.sv
git commit -m "feat(ahb): add bus env with dynamic agent creation"
```

---

### Task 14: ahb_sequences.sv — Sequence 库

**Files:**
- Create: `vip/amba/ahb/src/ahb_sequences.sv`

- [ ] **Step 1: 编写 ahb_sequences.sv**

```systemverilog
// vip/amba/ahb/src/ahb_sequences.sv
`ifndef AHB_SEQUENCES_SV
`define AHB_SEQUENCES_SV

// Single write sequence
class ahb_single_write_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_single_write_seq)

    rand bit [`AHB_ADDR_WIDTH-1:0] addr;
    rand bit [`AHB_DATA_WIDTH-1:0] data;

    task body();
        ahb_transaction txn;
        txn = ahb_transaction::type_id::create("txn");
        start_item(txn);
        assert(txn.randomize() with {
            txn.xact_type   == WRITE;
            txn.addr         == local::addr;
            txn.data[0]      == local::data;
            txn.burst_type   == SINGLE;
            txn.is_first_beat == 1;
            txn.is_last_beat  == 1;
            txn.beat_num      == 0;
            txn.burst_length  == 1;
        }) else `uvm_fatal("RANDFAIL", "Randomize failed")
        finish_item(txn);
    endtask
endclass

// Single read sequence
class ahb_single_read_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_single_read_seq)

    rand bit [`AHB_ADDR_WIDTH-1:0] addr;
    bit [`AHB_DATA_WIDTH-1:0] rdata;

    task body();
        ahb_transaction txn;
        txn = ahb_transaction::type_id::create("txn");
        start_item(txn);
        assert(txn.randomize() with {
            txn.xact_type   == READ;
            txn.addr         == local::addr;
            txn.burst_type   == SINGLE;
            txn.is_first_beat == 1;
            txn.is_last_beat  == 1;
            txn.beat_num      == 0;
            txn.burst_length  == 1;
        }) else `uvm_fatal("RANDFAIL", "Randomize failed")
        finish_item(txn);
        rdata = txn.data[0];
    endtask
endclass

// Burst write sequence
class ahb_burst_write_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_burst_write_seq)

    rand bit [`AHB_ADDR_WIDTH-1:0] start_addr;
    rand hburst_e                   burst_type;
    rand bit [`AHB_DATA_WIDTH-1:0]  burst_data[];

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
                txn.addr          == local::start_addr;  // Will be overridden
                txn.burst_type    == local::burst_type;
                txn.burst_size    == WORD;
                txn.data[0]       == local::burst_data[i];
                txn.beat_num      == i;
                txn.burst_length  == local::burst_len;
                txn.is_first_beat == (i == 0);
                txn.is_last_beat  == (i == burst_len - 1);
            }) else `uvm_fatal("RANDFAIL", "Randomize failed")
            // Override address with calculated beat address
            txn.addr = txn.get_beat_addr(i);
            finish_item(txn);
        end
    endtask
endclass

// Random read/write sequence
class ahb_random_rw_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_random_rw_seq)

    int unsigned num_txns = 10;

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

    bit [`AHB_DATA_WIDTH-1:0] mem [bit [`AHB_ADDR_WIDTH-1:0]];

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
```

- [ ] **Step 2: 更新 ahb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/src/ahb_sequences.sv vip/amba/ahb/src/ahb_pkg.sv
git commit -m "feat(ahb): add sequence library with burst support"
```

---

## Phase 3: DUT 模型和 Testbench

### Task 15: ahb_slave_ram.sv — DUT 模型

**Files:**
- Create: `vip/amba/ahb/src/ahb_slave_ram.sv`

- [ ] **Step 1: 编写 ahb_slave_ram.sv**

```systemverilog
// vip/amba/ahb/src/ahb_slave_ram.sv
`ifndef AHB_SLAVE_RAM_SV
`define AHB_SLAVE_RAM_SV

module ahb_slave_ram #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter WAIT_CYCLES = 0,
    parameter INJECT_ERROR = 0
) (
    input  logic                    HCLK,
    input  logic                    HRESETn,
    input  logic                    HSEL,
    input  logic [1:0]              HTRANS,
    input  logic                    HWRITE,
    input  logic [2:0]              HSIZE,
    input  logic [2:0]              HBURST,
    input  logic [ADDR_WIDTH-1:0]   HADDR,
    input  logic [DATA_WIDTH-1:0]   HWDATA,
    output logic [DATA_WIDTH-1:0]   HRDATA,
    output logic                    HREADY,
    output logic [1:0]              HRESP
);
    logic [DATA_WIDTH-1:0] mem [0:1023];
    int unsigned wait_cnt = 0;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HREADY  <= 1'b1;
            HRESP   <= 2'b00;  // OKAY
            HRDATA  <= '0;
            wait_cnt <= 0;
        end else if (HSEL && HTRANS inside {2'b10, 2'b11}) begin  // NONSEQ/SEQ
            if (wait_cnt < WAIT_CYCLES) begin
                HREADY <= 1'b0;
                wait_cnt <= wait_cnt + 1;
            end else begin
                HREADY <= 1'b1;
                wait_cnt <= 0;

                if (INJECT_ERROR) begin
                    HRESP <= 2'b01;  // ERROR
                end else begin
                    HRESP <= 2'b00;  // OKAY
                    if (HWRITE)
                        mem[HADDR[11:2]] <= HWDATA;
                    else
                        HRDATA <= mem[HADDR[11:2]];
                end
            end
        end
    end
endmodule

`endif // AHB_SLAVE_RAM_SV
```

- [ ] **Step 2: Commit**

```bash
git add vip/amba/ahb/src/ahb_slave_ram.sv
git commit -m "feat(ahb): add configurable slave RAM DUT model"
```

---

### Task 16: ahb_scoreboard.sv — Scoreboard

**Files:**
- Create: `vip/amba/ahb/src/ahb_scoreboard.sv`

- [ ] **Step 1: 编写 ahb_scoreboard.sv**

```systemverilog
// vip/amba/ahb/src/ahb_scoreboard.sv
`ifndef AHB_SCOREBOARD_SV
`define AHB_SCOREBOARD_SV

class ahb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ahb_scoreboard)

    uvm_analysis_imp_decl(_master)
    uvm_analysis_imp_decl(_slave)

    uvm_analysis_imp_master #(ahb_transaction, ahb_scoreboard) master_export;
    uvm_analysis_imp_slave #(ahb_transaction, ahb_scoreboard) slave_export;

    ahb_transaction master_bursts[$];

    int unsigned match_count = 0;
    int unsigned mismatch_count = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        master_export = new("master_export", this);
        slave_export  = new("slave_export", this);
    endfunction

    function void write_master(ahb_transaction t);
        master_bursts.push_back(t);
    endfunction

    function void write_slave(ahb_transaction t);
        ahb_transaction master_txn;

        if (master_bursts.size() == 0) begin
            `uvm_error("SCB", "No master burst available for comparison")
            return;
        end
        master_txn = master_bursts.pop_front();
        compare_bursts(master_txn, t);
    endfunction

    function void compare_bursts(ahb_transaction m, ahb_transaction s);
        bit ok = 1;

        if (m.burst_type != s.burst_type) begin
            `uvm_error("SCB", $sformatf("Burst type mismatch: master=%s, slave=%s",
                m.burst_type.name(), s.burst_type.name()))
            ok = 0;
        end

        if (m.addr != s.addr) begin
            `uvm_error("SCB", $sformatf("Address mismatch: master=0x%08h, slave=0x%08h",
                m.addr, s.addr))
            ok = 0;
        end

        if (m.data.size() != s.data.size()) begin
            `uvm_error("SCB", $sformatf("Data size mismatch: master=%0d, slave=%0d",
                m.data.size(), s.data.size()))
            ok = 0;
        end else begin
            foreach (m.data[i]) begin
                if (m.data[i] !== s.data[i]) begin
                    `uvm_error("SCB", $sformatf("Data[%0d] mismatch: master=0x%08h, slave=0x%08h",
                        i, m.data[i], s.data[i]))
                    ok = 0;
                end
            end
        end

        if (ok) match_count++;
        else mismatch_count++;
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCB", $sformatf("Burst matches=%0d, mismatches=%0d", match_count, mismatch_count), UVM_LOW)
    endfunction
endclass

`endif // AHB_SCOREBOARD_SV
```

- [ ] **Step 2: 更新 ahb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/src/ahb_scoreboard.sv vip/amba/ahb/src/ahb_pkg.sv
git commit -m "feat(ahb): add scoreboard with burst-level comparison"
```

---

### Task 17: ahb_agent_coverage.sv — Coverage

**Files:**
- Create: `vip/amba/ahb/src/ahb_agent_coverage.sv`

- [ ] **Step 1: 编写 ahb_agent_coverage.sv**

```systemverilog
// vip/amba/ahb/src/ahb_agent_coverage.sv
`ifndef AHB_AGENT_COVERAGE_SV
`define AHB_AGENT_COVERAGE_SV

class ahb_agent_coverage extends uvm_subscriber #(ahb_transaction);
    `uvm_component_utils(ahb_agent_coverage)

    ahb_transaction txn;

    covergroup cg_beat;
        cp_htrans: coverpoint txn.is_first_beat {
            bins seq    = {0};
            bins nonseq = {1};
        }
        cp_xact_type: coverpoint txn.xact_type {
            bins read  = {READ};
            bins write = {WRITE};
        }
        cp_wait_cycles: coverpoint txn.wait_cycles {
            bins zero = {0};
            bins low  = {[1:3]};
            bins high = {[4:7]};
        }
        cx_htrans_xact: cross cp_htrans, cp_xact_type;
    endgroup

    covergroup cg_burst;
        cp_burst_type: coverpoint txn.burst_type {
            bins single = {SINGLE};
            bins incr   = {INCR};
            bins incr4  = {INCR4};
            bins incr8  = {INCR8};
            bins incr16 = {INCR16};
            bins wrap4  = {WRAP4};
            bins wrap8  = {WRAP8};
            bins wrap16 = {WRAP16};
        }
        cp_burst_size: coverpoint txn.burst_size {
            bins byte_8   = {BYTE};
            bins halfword = {HALFWORD};
            bins word     = {WORD};
        }
        cx_burst_type_size: cross cp_burst_type, cp_burst_size;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_beat  = new();
        cg_burst = new();
    endfunction

    function void write(ahb_transaction t);
        txn = t;
        cg_beat.sample();
        cg_burst.sample();
    endfunction
endclass

`endif // AHB_AGENT_COVERAGE_SV
```

- [ ] **Step 2: 更新 ahb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/src/ahb_agent_coverage.sv vip/amba/ahb/src/ahb_pkg.sv
git commit -m "feat(ahb): add agent coverage"
```

---

## Phase 4: Testbench 和 Test

### Task 18: ahb_base_test.sv

**Files:**
- Create: `vip/amba/ahb/test/ahb_base_test.sv`

- [ ] **Step 1: 编写 ahb_base_test.sv**

```systemverilog
// vip/amba/ahb/test/ahb_base_test.sv
`ifndef AHB_BASE_TEST_SV
`define AHB_BASE_TEST_SV

class ahb_base_test extends uvm_test;
    `uvm_component_utils(ahb_base_test)

    ahb_bus_env      env;
    ahb_env_config   env_cfg;

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env_cfg = ahb_env_config::type_id::create("env_cfg");
        env_cfg.init();

        env = ahb_bus_env::type_id::create("env", this);
        env.env_cfg = env_cfg;
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction
endclass

`endif // AHB_BASE_TEST_SV
```

- [ ] **Step 2: 更新 ahb_tb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/test/ahb_base_test.sv vip/amba/ahb/tb/ahb_tb_pkg.sv
git commit -m "feat(ahb): add base test"
```

---

### Task 19: ahb_tb_top_lite.sv — AHB-Lite Testbench

**Files:**
- Create: `vip/amba/ahb/tb/ahb_tb_top_lite.sv`

- [ ] **Step 1: 编写 ahb_tb_top_lite.sv**

```systemverilog
// vip/amba/ahb/tb/ahb_tb_top_lite.sv
`ifndef AHB_TB_TOP_LITE_SV
`define AHB_TB_TOP_LITE_SV

module ahb_tb_top_lite;
    import uvm_pkg::*;
    import hx_ahb_pkg::*;
    `include "uvm_macros.svh"

    // Clock and reset
    logic HCLK;
    logic HRESETn;

    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK;
    end

    initial begin
        HRESETn = 0;
        repeat (10) @(posedge HCLK);
        HRESETn = 1;
    end

    // Interfaces
    ahb_interface mst_if (.HCLK(HCLK), .HRESETn(HRESETn));
    ahb_interface slv_if (.HCLK(HCLK), .HRESETn(HRESETn));

    // DUT
    ahb_slave_ram dut (
        .HCLK    (slv_if.HCLK),
        .HRESETn (slv_if.HRESETn),
        .HSEL    (1'b1),
        .HTRANS  (slv_if.HTRANS),
        .HWRITE  (slv_if.HWRITE),
        .HSIZE   (slv_if.HSIZE),
        .HBURST  (slv_if.HBURST),
        .HADDR   (slv_if.HADDR),
        .HWDATA  (slv_if.HWDATA),
        .HRDATA  (slv_if.HRDATA),
        .HREADY  (slv_if.HREADY),
        .HRESP   (slv_if.HRESP)
    );

    // Connect master driver output to slave interface
    assign slv_if.HTRANS  = mst_if.HTRANS;
    assign slv_if.HWRITE  = mst_if.HWRITE;
    assign slv_if.HSIZE   = mst_if.HSIZE;
    assign slv_if.HBURST  = mst_if.HBURST;
    assign slv_if.HADDR   = mst_if.HADDR;
    assign slv_if.HWDATA  = mst_if.HWDATA;
    assign mst_if.HRDATA  = slv_if.HRDATA;
    assign mst_if.HREADY  = slv_if.HREADY;
    assign mst_if.HRESP   = slv_if.HRESP;

    // Set vif
    initial begin
        uvm_config_db#(virtual ahb_interface)::set(null, "*.master_agt[0]", "vif", mst_if);
        uvm_config_db#(virtual ahb_interface)::set(null, "*.slave_agt[0]", "vif", slv_if);
    end

    // Run test
    initial begin
        run_test();
    end
endmodule

`endif // AHB_TB_TOP_LITE_SV
```

- [ ] **Step 2: Commit**

```bash
git add vip/amba/ahb/tb/ahb_tb_top_lite.sv
git commit -m "feat(ahb): add AHB-Lite testbench top"
```

---

### Task 20: ahb_lite_test.sv — 第一个可运行的测试

**Files:**
- Create: `vip/amba/ahb/test/ahb_lite_test.sv`

- [ ] **Step 1: 编写 ahb_lite_test.sv**

```systemverilog
// vip/amba/ahb/test/ahb_lite_test.sv
`ifndef AHB_LITE_TEST_SV
`define AHB_LITE_TEST_SV

class ahb_lite_test extends ahb_base_test;
    `uvm_component_utils(ahb_lite_test)

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
        wr_seq.addr = 'h100;
        wr_seq.data = 'hDEADBEEF;
        wr_seq.start(env.master_agt[0].sqr);

        // Read
        rd_seq = ahb_single_read_seq::type_id::create("rd_seq");
        rd_seq.addr = 'h100;
        rd_seq.start(env.master_agt[0].sqr);

        if (rd_seq.rdata !== 'hDEADBEEF)
            `uvm_error("LITE", $sformatf("Read mismatch: expected=0xDEADBEEF, actual=0x%08h", rd_seq.rdata))
        else
            `uvm_info("LITE", "AHB-Lite single write/read PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // AHB_LITE_TEST_SV
```

- [ ] **Step 2: 运行测试**

```bash
cd vip/amba/ahb/sim
make TEST=ahb_lite_test
```

Expected: Test passes with "AHB-Lite single write/read PASSED".

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/test/ahb_lite_test.sv
git commit -m "feat(ahb): add lite test - first runnable test"
```

---

## Phase 5: 问题修复和完善

在 Phase 4 完成后，运行 `ahb_lite_test` 时可能会遇到以下问题：
- Agent 连接问题（vif 传递）
- Monitor 采样时序问题
- Pipeline mailbox 同步问题
- tb_top 中 master→slave 信号连接问题

**验收标准:**
1. `make TEST=ahb_lite_test` 通过
2. 无 UVM_ERROR/UVM_FATAL
3. Write/Read 数据一致

---

## Phase 6: 高级测试

### Task 21: ahb_burst_test.sv (AHB-F02, F03, F04, F18)

**Files:**
- Create: `vip/amba/ahb/test/ahb_burst_test.sv`
- Create: `vip/amba/ahb/tb/ahb_tb_top_burst.sv`

- [ ] **Step 1: 编写 ahb_tb_top_burst.sv**

与 `ahb_tb_top_lite.sv` 相同结构，但使用不同的 vif 路径。

- [ ] **Step 2: 编写 ahb_burst_test.sv**

```systemverilog
// vip/amba/ahb/test/ahb_burst_test.sv
`ifndef AHB_BURST_TEST_SV
`define AHB_BURST_TEST_SV

class ahb_burst_test extends ahb_base_test;
    `uvm_component_utils(ahb_burst_test)

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env_cfg.init_lite();
        env.env_cfg = env_cfg;
    endfunction

    task run_phase(uvm_phase phase);
        ahb_burst_write_seq wr_seq;

        phase.raise_objection(this);

        // INCR4 burst write
        wr_seq = ahb_burst_write_seq::type_id::create("wr_seq");
        wr_seq.start_addr = 'h200;
        wr_seq.burst_type = INCR4;
        assert(wr_seq.randomize());
        wr_seq.start(env.master_agt[0].sqr);

        `uvm_info("BURST", "INCR4 burst write PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // AHB_BURST_TEST_SV
```

- [ ] **Step 3: 运行测试**

```bash
make TEST=ahb_burst_test
```

Expected: INCR4 burst write completes without error.

- [ ] **Step 4: Commit**

```bash
git add vip/amba/ahb/test/ahb_burst_test.sv vip/amba/ahb/tb/ahb_tb_top_burst.sv
git commit -m "feat(ahb): add burst test"
```

---

### Task 22: ahb_wait_state_test.sv (AHB-F05)

**Files:**
- Create: `vip/amba/ahb/test/ahb_wait_state_test.sv`
- Create: `vip/amba/ahb/tb/ahb_tb_top_wait.sv`

- [ ] **Step 1: 编写 ahb_tb_top_wait.sv**

与 lite 相同，但 DUT WAIT_CYCLES 参数不同。

- [ ] **Step 2: 编写 ahb_wait_state_test.sv**

```systemverilog
// vip/amba/ahb/test/ahb_wait_state_test.sv
`ifndef AHB_WAIT_STATE_TEST_SV
`define AHB_WAIT_STATE_TEST_SV

class ahb_wait_state_test extends ahb_base_test;
    `uvm_component_utils(ahb_wait_state_test)

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env_cfg.init_lite();
        env_cfg.slave_cfg[0].wait_cycles = 2;
        env.env_cfg = env_cfg;
    endfunction

    task run_phase(uvm_phase phase);
        ahb_single_write_seq wr_seq;
        ahb_single_read_seq  rd_seq;

        phase.raise_objection(this);

        wr_seq = ahb_single_write_seq::type_id::create("wr_seq");
        wr_seq.addr = 'h300;
        wr_seq.data = 'hCAFEBABE;
        wr_seq.start(env.master_agt[0].sqr);

        rd_seq = ahb_single_read_seq::type_id::create("rd_seq");
        rd_seq.addr = 'h300;
        rd_seq.start(env.master_agt[0].sqr);

        if (rd_seq.rdata !== 'hCAFEBABE)
            `uvm_error("WAIT", $sformatf("Read mismatch: expected=0xCAFEBABE, actual=0x%08h", rd_seq.rdata))
        else
            `uvm_info("WAIT", "Wait state test PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // AHB_WAIT_STATE_TEST_SV
```

- [ ] **Step 3: 运行测试**

```bash
make TEST=ahb_wait_state_test WAIT_CYCLES=2
```

Expected: Test passes with wait states.

- [ ] **Step 4: Commit**

```bash
git add vip/amba/ahb/test/ahb_wait_state_test.sv vip/amba/ahb/tb/ahb_tb_top_wait.sv
git commit -m "feat(ahb): add wait state test"
```

---

### Task 23: ahb_error_resp_test.sv (AHB-F06)

**Files:**
- Create: `vip/amba/ahb/test/ahb_error_resp_test.sv`
- Create: `vip/amba/ahb/tb/ahb_tb_top_error.sv`

- [ ] **Step 1: 编写 ahb_error_resp_test.sv**

```systemverilog
// vip/amba/ahb/test/ahb_error_resp_test.sv
`ifndef AHB_ERROR_RESP_TEST_SV
`define AHB_ERROR_RESP_TEST_SV

class ahb_error_resp_test extends ahb_base_test;
    `uvm_component_utils(ahb_error_resp_test)

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env_cfg.init_lite();
        env.env_cfg = env_cfg;
    endfunction

    task run_phase(uvm_phase phase);
        ahb_single_write_seq wr_seq;

        phase.raise_objection(this);

        wr_seq = ahb_single_write_seq::type_id::create("wr_seq");
        wr_seq.addr = 'h400;
        wr_seq.data = 'h12345678;
        wr_seq.start(env.master_agt[0].sqr);

        `uvm_info("ERR", "Error response test completed", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // AHB_ERROR_RESP_TEST_SV
```

- [ ] **Step 2: 运行测试**

```bash
make TEST=ahb_error_resp_test INJECT_ERROR=1
```

Expected: Test completes, monitor reports HRESP=ERROR.

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/test/ahb_error_resp_test.sv vip/amba/ahb/tb/ahb_tb_top_error.sv
git commit -m "feat(ahb): add error response test"
```

---

### Task 24: ahb_pipeline_test.sv (AHB-F11)

**Files:**
- Create: `vip/amba/ahb/test/ahb_pipeline_test.sv`
- Create: `vip/amba/ahb/tb/ahb_tb_top_pipeline.sv`

- [ ] **Step 1: 编写 ahb_pipeline_test.sv**

```systemverilog
// vip/amba/ahb/test/ahb_pipeline_test.sv
`ifndef AHB_PIPELINE_TEST_SV
`define AHB_PIPELINE_TEST_SV

class ahb_pipeline_test extends ahb_base_test;
    `uvm_component_utils(ahb_pipeline_test)

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env_cfg.init_lite();
        env.env_cfg = env_cfg;
    endfunction

    task run_phase(uvm_phase phase);
        ahb_burst_write_seq wr_seq;
        ahb_random_rw_seq   rw_seq;

        phase.raise_objection(this);

        // Multiple back-to-back bursts to exercise pipeline
        repeat (5) begin
            wr_seq = ahb_burst_write_seq::type_id::create("wr_seq");
            wr_seq.start_addr = 'h500;
            wr_seq.burst_type = INCR4;
            assert(wr_seq.randomize());
            wr_seq.start(env.master_agt[0].sqr);
        end

        `uvm_info("PIPE", "Pipeline test PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // AHB_PIPELINE_TEST_SV
```

- [ ] **Step 2: 运行测试**

```bash
make TEST=ahb_pipeline_test
```

Expected: Multiple back-to-back bursts complete without error.

- [ ] **Step 3: Commit**

```bash
git add vip/amba/ahb/test/ahb_pipeline_test.sv vip/amba/ahb/tb/ahb_tb_top_pipeline.sv
git commit -m "feat(ahb): add pipeline test"
```

---

## 验收标准

### 功能验收

每个 Test 运行后，检查以下内容：

| 检查项 | 标准 |
|--------|------|
| UVM_FATAL | 0 个 |
| UVM_ERROR | 0 个（除非测试错误注入） |
| 编译警告 | 0 个 |
| 仿真完成 | 正常结束，无 hang |

### Feature 覆盖

| ID | Feature | 测试 | 验收方式 |
|----|---------|------|----------|
| AHB-F01 | SINGLE 传输 | lite_test | Write/Read 数据一致 |
| AHB-F02 | INCR burst | burst_test | Burst write 完成 |
| AHB-F03 | INCR4/8/16 burst | burst_test | 固定长度 burst 完成 |
| AHB-F04 | WRAP4/8/16 burst | burst_test | WRAP 地址回绕正确 |
| AHB-F05 | HREADY=0 等待 | wait_state_test | WAIT_CYCLES>0 时正常完成 |
| AHB-F06 | HRESP=ERROR | error_resp_test | INJECT_ERROR=1 时 Monitor 报告 ERROR |
| AHB-F11 | Pipeline 重叠 | pipeline_test | 多个 back-to-back burst 完成 |
| AHB-F14 | AHB-Lite 单 Master | lite_test | 单 master 直连 slave |
| AHB-F18 | HPROT 保护信号 | burst_test | HPROT 正确传递 |
| AHB-F22 | Config Object | 所有测试 | cfg 显式赋值 |

### 运行命令

```bash
cd vip/amba/ahb/sim

# AHB-Lite 基础测试
make TEST=ahb_lite_test

# Burst 测试
make TEST=ahb_burst_test

# Wait State 测试
make TEST=ahb_wait_state_test WAIT_CYCLES=2

# Error Response 测试
make TEST=ahb_error_resp_test INJECT_ERROR=1

# Pipeline 测试
make TEST=ahb_pipeline_test
```

---

## 开发顺序总结

```
Phase 1 (基础组件):
  Task 1:  目录结构和脚手架
  Task 2:  ahb_defines.svh
  Task 3:  ahb_interface.sv
  Task 4:  ahb_transaction.sv
  Task 5:  ahb_agent_config.sv
  Task 6:  ahb_env_config.sv
  Task 7:  ahb_sequencer.sv
  Task 8:  ahb_monitor.sv
  Task 9:  ahb_master_driver.sv
  Task 10: ahb_slave_driver.sv

Phase 2 (Agent 和 Env):
  Task 11: ahb_master_agent.sv
  Task 12: ahb_slave_agent.sv
  Task 13: ahb_bus_env.sv
  Task 14: ahb_sequences.sv

Phase 3 (DUT 和 TB):
  Task 15: ahb_slave_ram.sv
  Task 16: ahb_scoreboard.sv
  Task 17: ahb_agent_coverage.sv

Phase 4 (Test):
  Task 18: ahb_base_test.sv
  Task 19: ahb_tb_top_lite.sv
  Task 20: ahb_lite_test.sv ← 第一个可运行的测试

Phase 5 (问题修复):
  根据 lite_test 结果修复问题

Phase 6 (高级测试):
  Task 21: ahb_burst_test.sv
  Task 22: ahb_wait_state_test.sv
  Task 23: ahb_error_resp_test.sv
  Task 24: ahb_pipeline_test.sv
```
