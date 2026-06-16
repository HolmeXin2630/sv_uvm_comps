# APB VIP 开发计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `vip/amba/apb/` 下开发完整的 APB VIP，支持 APB3/4，产出可直接用于项目的验证 IP。

**Architecture:** 单一 Agent 通过 config 控制 master/slave 角色。Monitor 始终创建，Driver 根据 active 配置决定是否创建。采用依赖注入，cfg 显式赋值，config_db 仅用于传递 vif。

**Tech Stack:** SystemVerilog, UVM, VCS 仿真

**参考文档:**
- 设计文档: `docs/superpowers/specs/2026-06-06-amba-vip-design.md`
- 术语表: `CONTEXT.md`
- 编码规范: `vip/amba/uvm_coding_guidelines.md`
- Feature Checklist: `vip/amba/features_checklist.md`

---

## 文件结构

```
vip/amba/apb/
├── src/
│   ├── apb_defines.svh         # 宏定义
│   ├── apb_interface.sv        # 接口（含 clocking block）
│   ├── apb_transaction.sv      # Transaction
│   ├── apb_config.sv           # agent_config + system_config
│   ├── apb_sequencer.sv        # Sequencer
│   ├── apb_monitor.sv          # Monitor
│   ├── apb_driver.sv           # Master Driver
│   ├── apb_slave_driver.sv     # Slave Driver
│   ├── apb_agent.sv            # Agent（master/slave）
│   ├── apb_sequences.sv        # Sequence 库
│   ├── apb_coverage.sv         # Coverage
│   ├── apb_scoreboard.sv       # Scoreboard
│   └── apb_pkg.sv              # Package 封装
├── tb/
│   ├── apb_slave_ram.sv        # DUT 模型
│   ├── apb_tb_top.sv           # Testbench Top
│   └── apb_tb_pkg.sv           # TB Package
├── test/
│   ├── apb_base_test.sv        # Base Test
│   ├── apb_smoke_test.sv       # APB-F01, F02, F09, F12
│   ├── apb_random_test.sv      # APB-F05, F06
│   ├── apb_directed_test.sv    # APB-F13
│   ├── apb_wait_state_test.sv  # APB-F03
│   ├── apb_slverr_test.sv      # APB-F04
│   ├── apb_pstrb_test.sv       # APB-F10, F11
│   ├── apb_slave_agent_test.sv # APB-F07
│   └── apb_multi_slave_test.sv # APB-F08
└── sim/
    ├── Makefile
    └── .gitignore
```

---

## Phase 1: 基础组件

### Task 1: 创建目录结构和编译脚手架

**Files:**
- Create: `vip/amba/apb/sim/Makefile`
- Create: `vip/amba/apb/sim/.gitignore`
- Create: `vip/amba/apb/src/apb_pkg.sv`（骨架）
- Create: `vip/amba/apb/tb/apb_tb_pkg.sv`（骨架）

- [ ] **Step 1: 创建目录结构**

```bash
mkdir -p vip/amba/apb/{src,tb,test,sim}
```

- [ ] **Step 2: 创建 .gitignore**

```
# vip/amba/apb/sim/.gitignore
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
# vip/amba/apb/sim/Makefile
SIM_OUTPUT ?= $(CURDIR)/output

TEST ?= apb_smoke_test
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
	vcs $(COMPILE_OPTS) -o $(SIM_OUTPUT)/simv \
		../tb/apb_tb_top.sv

run:
	$(SIM_OUTPUT)/simv +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=UVM_MEDIUM

clean:
	rm -rf $(SIM_OUTPUT) csrc *.log *.key *.vpd *.vdb simv simv.daidir
```

- [ ] **Step 4: 创建 apb_pkg.sv 骨架**

```systemverilog
// vip/amba/apb/src/apb_pkg.sv
`ifndef APB_PKG_SV
`define APB_PKG_SV

package hx_apb_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // TODO: `include 所有组件
    // `include "apb_defines.svh"
    // `include "apb_transaction.sv"
    // ...

endpackage

`endif // APB_PKG_SV
```

- [ ] **Step 5: 创建 apb_tb_pkg.sv 骨架**

```systemverilog
// vip/amba/apb/tb/apb_tb_pkg.sv
`ifndef APB_TB_PKG_SV
`define APB_TB_PKG_SV

package hx_apb_tb_pkg;
    import uvm_pkg::*;
    import hx_apb_pkg::*;
    `include "uvm_macros.svh"

    // TODO: `include tb 和 test 文件
    // `include "apb_slave_ram.sv"
    // `include "apb_base_test.sv"
    // ...

endpackage

`endif // APB_TB_PKG_SV
```

- [ ] **Step 6: Commit**

```bash
git add vip/amba/apb/
git commit -m "feat(apb): create directory structure and scaffolding"
```

---

### Task 2: apb_defines.svh — 宏定义

**Files:**
- Create: `vip/amba/apb/src/apb_defines.svh`

- [ ] **Step 1: 编写 apb_defines.svh**

```systemverilog
// vip/amba/apb/src/apb_defines.svh
`ifndef APB_DEFINES_SVH
`define APB_DEFINES_SVH

// Width macros (can be overridden at compile time)
`ifndef APB_ADDR_WIDTH
`define APB_ADDR_WIDTH 32
`endif

`ifndef APB_DATA_WIDTH
`define APB_DATA_WIDTH 32
`endif

// Protocol version control
// `define APB_APB4_ENABLE  // Uncomment to enable APB4 features

`endif // APB_DEFINES_SVH
```

- [ ] **Step 2: 更新 apb_pkg.sv include**

在 `apb_pkg.sv` 中添加 `include "apb_defines.svh"`。

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/src/apb_defines.svh vip/amba/apb/src/apb_pkg.sv
git commit -m "feat(apb): add defines with width macros"
```

---

### Task 3: apb_interface.sv — 接口

**Files:**
- Create: `vip/amba/apb/src/apb_interface.sv`

- [ ] **Step 1: 编写 apb_interface.sv**

```systemverilog
// vip/amba/apb/src/apb_interface.sv
`ifndef APB_INTERFACE_SV
`define APB_INTERFACE_SV

interface apb_interface #(
    parameter ADDR_WIDTH = `APB_ADDR_WIDTH,
    parameter DATA_WIDTH = `APB_DATA_WIDTH
) (
    input logic PCLK,
    input logic PRESETn
);
    // Signal declarations
    logic                    PSEL;
    logic                    PENABLE;
    logic [ADDR_WIDTH-1:0]   PADDR;
    logic                    PWRITE;
    logic [DATA_WIDTH-1:0]   PWDATA;
    logic [DATA_WIDTH-1:0]   PRDATA;
    logic                    PREADY;
    logic                    PSLVERR;

`ifdef APB_APB4_ENABLE
    logic [DATA_WIDTH/8-1:0] PSTRB;
    logic [2:0]              PPROT;
`else
    logic [DATA_WIDTH/8-1:0] PSTRB;
    logic [2:0]              PPROT;
`endif

    // Master clocking block
    clocking master_cb @(posedge PCLK);
        default input #1 output #1;
        output PSEL;
        output PENABLE;
        output PADDR;
        output PWRITE;
        output PWDATA;
        output PSTRB;
        output PPROT;
        input  PRDATA;
        input  PREADY;
        input  PSLVERR;
    endclocking

    // Slave clocking block
    clocking slave_cb @(posedge PCLK);
        default input #1 output #1;
        input  PSEL;
        input  PENABLE;
        input  PADDR;
        input  PWRITE;
        input  PWDATA;
        input  PSTRB;
        input  PPROT;
        output PRDATA;
        output PREADY;
        output PSLVERR;
    endclocking

    // Monitor clocking block
    clocking monitor_cb @(posedge PCLK);
        default input #1 output #1;
        input PSEL;
        input PENABLE;
        input PADDR;
        input PWRITE;
        input PWDATA;
        input PRDATA;
        input PREADY;
        input PSLVERR;
        input PSTRB;
        input PPROT;
    endclocking

    // Modports
    modport master  (clocking master_cb,  input PRESETn);
    modport slave   (clocking slave_cb,   input PRESETn);
    modport monitor (clocking monitor_cb, input PRESETn);

endinterface

`endif // APB_INTERFACE_SV
```

- [ ] **Step 2: Commit**

```bash
git add vip/amba/apb/src/apb_interface.sv
git commit -m "feat(apb): add interface with clocking blocks"
```

---

### Task 4: apb_transaction.sv — Transaction

**Files:**
- Create: `vip/amba/apb/src/apb_transaction.sv`
- Test: 编译通过即可（后续 smoke_test 验证功能）

- [ ] **Step 1: 编写 apb_transaction.sv**

```systemverilog
// vip/amba/apb/src/apb_transaction.sv
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
```

- [ ] **Step 2: 更新 apb_pkg.sv**

在 `apb_pkg.sv` 中添加 `include "apb_transaction.sv"`。

- [ ] **Step 3: 编译验证**

```bash
cd vip/amba/apb/sim
make comp
```

Expected: 编译通过，无 error。

- [ ] **Step 4: Commit**

```bash
git add vip/amba/apb/src/apb_transaction.sv vip/amba/apb/src/apb_pkg.sv
git commit -m "feat(apb): add transaction with APB3/APB4 fields"
```

---

### Task 5: apb_config.sv — Config 对象

**Files:**
- Create: `vip/amba/apb/src/apb_config.sv`

- [ ] **Step 1: 编写 apb_config.sv**

```systemverilog
// vip/amba/apb/src/apb_config.sv
`ifndef APB_CONFIG_SV
`define APB_CONFIG_SV

// Agent Config
class apb_agent_config extends uvm_object;
    `uvm_object_utils(apb_agent_config)

    // Mode
    bit active = 1;  // 1=active (driver created), 0=passive (monitor only)

    // Width
    int addr_width = `APB_ADDR_WIDTH;
    int data_width = `APB_DATA_WIDTH;

    // APB4 enable
    bit apb4_enable = 0;

    // Virtual interface (set by tb_top via config_db)
    virtual apb_interface vif;

    function new(string name = "apb_agent_config");
        super.new(name);
    endfunction
endclass

// System Config
class apb_system_config extends uvm_object;
    `uvm_object_utils(apb_system_config)

    // Number of slaves
    int num_slaves = 1;

    // Agent configs
    apb_agent_config master_cfg;
    apb_agent_config slave_cfg[];

    // Slave address map: {base_addr, size} pairs
    bit [`APB_ADDR_WIDTH-1:0] slave_base_addr[];
    bit [`APB_ADDR_WIDTH-1:0] slave_size[];

    function new(string name = "apb_system_config");
        super.new(name);
    endfunction

    // Initialize
    function void init();
        master_cfg = apb_agent_config::type_id::create("master_cfg");
        master_cfg.active = 1;

        slave_cfg = new[num_slaves];
        slave_base_addr = new[num_slaves];
        slave_size = new[num_slaves];

        foreach (slave_cfg[i]) begin
            slave_cfg[i] = apb_agent_config::type_id::create($sformatf("slave_cfg[%0d]", i));
            slave_cfg[i].active = 1;
            slave_base_addr[i] = i * 'h1000;
            slave_size[i] = 'h1000;
        end
    endfunction
endclass

`endif // APB_CONFIG_SV
```

- [ ] **Step 2: 更新 apb_pkg.sv**

在 `apb_pkg.sv` 中添加 `include "apb_config.sv"`。

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/src/apb_config.sv vip/amba/apb/src/apb_pkg.sv
git commit -m "feat(apb): add agent and system config objects"
```

---

### Task 6: apb_sequencer.sv

**Files:**
- Create: `vip/amba/apb/src/apb_sequencer.sv`

- [ ] **Step 1: 编写 apb_sequencer.sv**

```systemverilog
// vip/amba/apb/src/apb_sequencer.sv
`ifndef APB_SEQUENCER_SV
`define APB_SEQUENCER_SV

class apb_sequencer extends uvm_sequencer #(apb_transaction);
    `uvm_component_utils(apb_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

`endif // APB_SEQUENCER_SV
```

- [ ] **Step 2: 更新 apb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/src/apb_sequencer.sv vip/amba/apb/src/apb_pkg.sv
git commit -m "feat(apb): add sequencer"
```

---

### Task 7: apb_monitor.sv — Monitor

**Files:**
- Create: `vip/amba/apb/src/apb_monitor.sv`

- [ ] **Step 1: 编写 apb_monitor.sv**

```systemverilog
// vip/amba/apb/src/apb_monitor.sv
`ifndef APB_MONITOR_SV
`define APB_MONITOR_SV

class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    virtual apb_interface.monitor_cb vif;
    uvm_analysis_port #(apb_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        apb_transaction txn;
        forever begin
            // Wait for SETUP: PSEL=1, PENABLE=0
            @(vif.monitor_cb);
            while (!(vif.monitor_cb.PSEL && !vif.monitor_cb.PENABLE))
                @(vif.monitor_cb);

            // Sample address and control
            txn = apb_transaction::type_id::create("txn");
            txn.addr  = vif.monitor_cb.PADDR;
            txn.write = vif.monitor_cb.PWRITE;
            `ifdef APB_APB4_ENABLE
            txn.strb = vif.monitor_cb.PSTRB;
            txn.prot = vif.monitor_cb.PPROT;
            `endif

            if (txn.write)
                txn.data = vif.monitor_cb.PWDATA;

            // Wait for ACCESS completion: PENABLE=1, PREADY=1
            @(vif.monitor_cb);
            while (!(vif.monitor_cb.PENABLE && vif.monitor_cb.PREADY))
                @(vif.monitor_cb);

            // Sample response
            if (!txn.write)
                txn.data = vif.monitor_cb.PRDATA;
            txn.slverr = vif.monitor_cb.PSLVERR;

            // Send to analysis port
            ap.write(txn);
        end
    endtask
endclass

`endif // APB_MONITOR_SV
```

- [ ] **Step 2: 更新 apb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/src/apb_monitor.sv vip/amba/apb/src/apb_pkg.sv
git commit -m "feat(apb): add monitor with SETUP/ACCESS detection"
```

---

### Task 8: apb_driver.sv — Master Driver

**Files:**
- Create: `vip/amba/apb/src/apb_driver.sv`

- [ ] **Step 1: 编写 apb_driver.sv**

```systemverilog
// vip/amba/apb/src/apb_driver.sv
`ifndef APB_DRIVER_SV
`define APB_DRIVER_SV

class apb_driver extends uvm_driver #(apb_transaction);
    `uvm_component_utils(apb_driver)

    virtual apb_interface.master_cb vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_transaction txn;
        forever begin
            seq_item_port.get(txn);

            // Idle cycles
            repeat (txn.idle_cycles) @(vif.master_cb);

            // SETUP phase: PSEL=1, PENABLE=0
            @(vif.master_cb);
            vif.master_cb.PSEL    <= 1'b1;
            vif.master_cb.PENABLE <= 1'b0;
            vif.master_cb.PADDR   <= txn.addr;
            vif.master_cb.PWRITE  <= txn.write;
            if (txn.write)
                vif.master_cb.PWDATA <= txn.data;
            `ifdef APB_APB4_ENABLE
            vif.master_cb.PSTRB <= txn.strb;
            vif.master_cb.PPROT <= txn.prot;
            `endif

            // ACCESS phase: PENABLE=1
            @(vif.master_cb);
            vif.master_cb.PENABLE <= 1'b1;

            // Wait for PREADY
            while (!vif.master_cb.PREADY) @(vif.master_cb);

            // Sample response for read
            if (!txn.write)
                txn.data = vif.master_cb.PRDATA;
            txn.slverr = vif.master_cb.PSLVERR;

            // Return to IDLE
            @(vif.master_cb);
            vif.master_cb.PSEL    <= 1'b0;
            vif.master_cb.PENABLE <= 1'b0;
        end
    endtask
endclass

`endif // APB_DRIVER_SV
```

- [ ] **Step 2: 更新 apb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/src/apb_driver.sv vip/amba/apb/src/apb_pkg.sv
git commit -m "feat(apb): add master driver with SETUP/ACCESS FSM"
```

---

### Task 9: apb_slave_driver.sv — Slave Driver

**Files:**
- Create: `vip/amba/apb/src/apb_slave_driver.sv`

- [ ] **Step 1: 编写 apb_slave_driver.sv**

```systemverilog
// vip/amba/apb/src/apb_slave_driver.sv
`ifndef APB_SLAVE_DRIVER_SV
`define APB_SLAVE_DRIVER_SV

class apb_slave_driver extends uvm_driver #(apb_transaction);
    `uvm_component_utils(apb_slave_driver)

    virtual apb_interface.slave_cb vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_transaction rsp;
        forever begin
            // Wait for SETUP: PSEL=1, PENABLE=0
            @(vif.slave_cb);
            while (!(vif.slave_cb.PSEL && !vif.slave_cb.PENABLE))
                @(vif.slave_cb);

            // Get response from sequencer
            seq_item_port.get(rsp);

            // Wait for ACCESS: PENABLE=1
            @(vif.slave_cb);
            while (!(vif.slave_cb.PENABLE && vif.slave_cb.PREADY))
                @(vif.slave_cb);

            // Drive response
            vif.slave_cb.PRDATA  <= rsp.data;
            vif.slave_cb.PSLVERR <= rsp.slverr;
        end
    endtask
endclass

`endif // APB_SLAVE_DRIVER_SV
```

- [ ] **Step 2: 更新 apb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/src/apb_slave_driver.sv vip/amba/apb/src/apb_pkg.sv
git commit -m "feat(apb): add slave driver"
```

---

### Task 10: apb_agent.sv — Agent

**Files:**
- Create: `vip/amba/apb/src/apb_agent.sv`

- [ ] **Step 1: 编写 apb_agent.sv**

```systemverilog
// vip/amba/apb/src/apb_agent.sv
`ifndef APB_AGENT_SV
`define APB_AGENT_SV

class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    // Exposed API
    apb_agent_config cfg;
    apb_sequencer    sqr;

    // Internal
    apb_driver       drv;
    apb_slave_driver slave_drv;
    apb_monitor      mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Create monitor (always)
        mon = apb_monitor::type_id::create("mon", this);

        // Create driver based on active config
        if (cfg.active) begin
            if (cfg.master_mode) begin
                drv = apb_driver::type_id::create("drv", this);
                sqr = apb_sequencer::type_id::create("sqr", this);
            end else begin
                slave_drv = apb_slave_driver::type_id::create("slave_drv", this);
                sqr = apb_sequencer::type_id::create("sqr", this);
            end
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Pass vif to components
        mon.vif = cfg.vif;
        if (cfg.active) begin
            if (cfg.master_mode) begin
                drv.vif = cfg.vif;
                drv.seq_item_port.connect(sqr.seq_item_export);
            end else begin
                slave_drv.vif = cfg.vif;
                slave_drv.seq_item_port.connect(sqr.seq_item_export);
            end
        end
    endfunction
endclass

`endif // APB_AGENT_SV
```

- [ ] **Step 2: 更新 apb_agent_config 添加 master_mode 字段**

在 `apb_config.sv` 的 `apb_agent_config` 中添加 `bit master_mode = 1;`。

- [ ] **Step 3: 更新 apb_pkg.sv**

- [ ] **Step 4: Commit**

```bash
git add vip/amba/apb/src/apb_agent.sv vip/amba/apb/src/apb_config.sv vip/amba/apb/src/apb_pkg.sv
git commit -m "feat(apb): add agent with master/slave mode support"
```

---

## Phase 2: DUT 模型和 Testbench

### Task 11: apb_slave_ram.sv — DUT 模型

**Files:**
- Create: `vip/amba/apb/tb/apb_slave_ram.sv`

- [ ] **Step 1: 编写 apb_slave_ram.sv**

```systemverilog
// vip/amba/apb/tb/apb_slave_ram.sv
`ifndef APB_SLAVE_RAM_SV
`define APB_SLAVE_RAM_SV

module apb_slave_ram #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter WAIT_CYCLES = 0,
    parameter INJECT_ERROR = 0
) (
    input  logic                    PCLK,
    input  logic                    PRESETn,
    input  logic                    PSEL,
    input  logic                    PENABLE,
    input  logic                    PWRITE,
    input  logic [ADDR_WIDTH-1:0]   PADDR,
    input  logic [DATA_WIDTH-1:0]   PWDATA,
    output logic [DATA_WIDTH-1:0]   PRDATA,
    output logic                    PREADY,
    output logic                    PSLVERR
);
    logic [DATA_WIDTH-1:0] mem [0:1023];
    int unsigned wait_cnt = 0;

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PREADY  <= 1'b1;
            PSLVERR <= 1'b0;
            PRDATA  <= '0;
            wait_cnt <= 0;
        end else if (PSEL && PENABLE) begin
            if (wait_cnt < WAIT_CYCLES) begin
                PREADY <= 1'b0;
                wait_cnt <= wait_cnt + 1;
            end else begin
                PREADY <= 1'b1;
                wait_cnt <= 0;

                if (INJECT_ERROR) begin
                    PSLVERR <= 1'b1;
                end else begin
                    PSLVERR <= 1'b0;
                    if (PWRITE)
                        mem[PADDR[11:2]] <= PWDATA;
                    else
                        PRDATA <= mem[PADDR[11:2]];
                end
            end
        end
    end
endmodule

`endif // APB_SLAVE_RAM_SV
```

- [ ] **Step 2: Commit**

```bash
git add vip/amba/apb/tb/apb_slave_ram.sv
git commit -m "feat(apb): add configurable slave RAM DUT model"
```

---

### Task 12: apb_tb_top.sv — Testbench Top

**Files:**
- Create: `vip/amba/apb/tb/apb_tb_top.sv`

- [ ] **Step 1: 编写 apb_tb_top.sv**

```systemverilog
// vip/amba/apb/tb/apb_tb_top.sv
`ifndef APB_TB_TOP_SV
`define APB_TB_TOP_SV

module apb_tb_top;
    import uvm_pkg::*;
    import hx_apb_pkg::*;
    `include "uvm_macros.svh"

    // Clock and reset
    logic PCLK;
    logic PRESETn;

    initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK;
    end

    initial begin
        PRESETn = 0;
        repeat (10) @(posedge PCLK);
        PRESETn = 1;
    end

    // Interface
    apb_interface apb_if (.PCLK(PCLK), .PRESETn(PRESETn));

    // DUT
    apb_slave_ram #(
        .WAIT_CYCLES(0),
        .INJECT_ERROR(0)
    ) dut (
        .PCLK    (apb_if.PCLK),
        .PRESETn (apb_if.PRESETn),
        .PSEL    (apb_if.PSEL),
        .PENABLE (apb_if.PENABLE),
        .PWRITE  (apb_if.PWRITE),
        .PADDR   (apb_if.PADDR),
        .PWDATA  (apb_if.PWDATA),
        .PRDATA  (apb_if.PRDATA),
        .PREADY  (apb_if.PREADY),
        .PSLVERR (apb_if.PSLVERR)
    );

    // Set vif
    initial begin
        uvm_config_db#(virtual apb_interface)::set(null, "*.apb_agt", "vif", apb_if);
    end

    // Run test
    initial begin
        run_test();
    end
endmodule

`endif // APB_TB_TOP_SV
```

- [ ] **Step 2: Commit**

```bash
git add vip/amba/apb/tb/apb_tb_top.sv
git commit -m "feat(apb): add testbench top with clock/reset and DUT"
```

---

### Task 13: apb_sequences.sv — Sequence 库

**Files:**
- Create: `vip/amba/apb/src/apb_sequences.sv`

- [ ] **Step 1: 编写 apb_sequences.sv**

```systemverilog
// vip/amba/apb/src/apb_sequences.sv
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
```

- [ ] **Step 2: 更新 apb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/src/apb_sequences.sv vip/amba/apb/src/apb_pkg.sv
git commit -m "feat(apb): add write, read, rw, and slave response sequences"
```

---

### Task 14: apb_base_test.sv — Base Test

**Files:**
- Create: `vip/amba/apb/test/apb_base_test.sv`

- [ ] **Step 1: 编写 apb_base_test.sv**

```systemverilog
// vip/amba/apb/test/apb_base_test.sv
`ifndef APB_BASE_TEST_SV
`define APB_BASE_TEST_SV

class apb_base_test extends uvm_test;
    `uvm_component_utils(apb_base_test)

    // Components
    apb_agent         apb_agt;
    apb_system_config sys_cfg;

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Create system config
        sys_cfg = apb_system_config::type_id::create("sys_cfg");
        sys_cfg.init();

        // Create agent
        apb_agt = apb_agent::type_id::create("apb_agt", this);

        // Inject config (dependency injection)
        apb_agt.cfg = sys_cfg.master_cfg;
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction
endclass

`endif // APB_BASE_TEST_SV
```

- [ ] **Step 2: 更新 apb_tb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/test/apb_base_test.sv vip/amba/apb/tb/apb_tb_pkg.sv
git commit -m "feat(apb): add base test with default config"
```

---

### Task 15: apb_smoke_test.sv — Smoke Test (APB-F01, F02, F09, F12)

**Files:**
- Create: `vip/amba/apb/test/apb_smoke_test.sv`

- [ ] **Step 1: 编写 apb_smoke_test.sv**

```systemverilog
// vip/amba/apb/test/apb_smoke_test.sv
`ifndef APB_SMOKE_TEST_SV
`define APB_SMOKE_TEST_SV

class apb_smoke_test extends apb_base_test;
    `uvm_component_utils(apb_smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_write_seq wr_seq;
        apb_read_seq  rd_seq;

        phase.raise_objection(this);

        // Write to address 0x0000_0100
        wr_seq = apb_write_seq::type_id::create("wr_seq");
        wr_seq.addr = 'h100;
        wr_seq.data = 'hDEADBEEF;
        wr_seq.start(apb_agt.sqr);

        // Read from address 0x0000_0100
        rd_seq = apb_read_seq::type_id::create("rd_seq");
        rd_seq.addr = 'h100;
        rd_seq.start(apb_agt.sqr);

        // Verify read data
        if (rd_seq.rdata !== 'hDEADBEEF)
            `uvm_error("SMOKE", $sformatf("Read data mismatch: expected=0xDEADBEEF, actual=0x%08h", rd_seq.rdata))
        else
            `uvm_info("SMOKE", "Write/Read test PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // APB_SMOKE_TEST_SV
```

- [ ] **Step 2: 运行 smoke test**

```bash
cd vip/amba/apb/sim
make TEST=apb_smoke_test
```

Expected: Test passes with "Write/Read test PASSED" message.

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/test/apb_smoke_test.sv
git commit -m "feat(apb): add smoke test for basic write/read"
```

---

## Phase 3: 问题修复和完善

在 Phase 2 完成后，运行 smoke test 时可能会遇到以下问题：
- Agent 连接问题（Slave Driver 模式下的连接）
- Monitor 采样时机问题
- 编译顺序问题

**验收标准:**
1. `make TEST=apb_smoke_test` 通过
2. 无 UVM_ERROR/UVM_FATAL
3. Write/Read 数据一致

---

## Phase 4: 高级测试

### Task 16: apb_wait_state_test.sv (APB-F03)

**Files:**
- Create: `vip/amba/apb/test/apb_wait_state_test.sv`

- [ ] **Step 1: 编写 apb_wait_state_test.sv**

```systemverilog
// vip/amba/apb/test/apb_wait_state_test.sv
`ifndef APB_WAIT_STATE_TEST_SV
`define APB_WAIT_STATE_TEST_SV

class apb_wait_state_test extends apb_base_test;
    `uvm_component_utils(apb_wait_state_test)

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Note: DUT WAIT_CYCLES is set via Makefile parameter
    endfunction

    task run_phase(uvm_phase phase);
        apb_write_seq wr_seq;
        apb_read_seq  rd_seq;

        phase.raise_objection(this);

        wr_seq = apb_write_seq::type_id::create("wr_seq");
        wr_seq.addr = 'h200;
        wr_seq.data = 'hCAFEBABE;
        wr_seq.start(apb_agt.sqr);

        rd_seq = apb_read_seq::type_id::create("rd_seq");
        rd_seq.addr = 'h200;
        rd_seq.start(apb_agt.sqr);

        if (rd_seq.rdata !== 'hCAFEBABE)
            `uvm_error("WAIT", $sformatf("Read data mismatch: expected=0xCAFEBABE, actual=0x%08h", rd_seq.rdata))
        else
            `uvm_info("WAIT", "Wait state test PASSED", UVM_LOW)

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // APB_WAIT_STATE_TEST_SV
```

- [ ] **Step 2: 运行测试**

```bash
make TEST=apb_wait_state_test WAIT_CYCLES=2
```

Expected: Test passes with wait states inserted by DUT.

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/test/apb_wait_state_test.sv
git commit -m "feat(apb): add wait state test"
```

---

### Task 17: apb_slverr_test.sv (APB-F04)

**Files:**
- Create: `vip/amba/apb/test/apb_slverr_test.sv`

- [ ] **Step 1: 编写 apb_slverr_test.sv**

```systemverilog
// vip/amba/apb/test/apb_slverr_test.sv
`ifndef APB_SLVERR_TEST_SV
`define APB_SLVERR_TEST_SV

class apb_slverr_test extends apb_base_test;
    `uvm_component_utils(apb_slverr_test)

    task run_phase(uvm_phase phase);
        apb_write_seq wr_seq;

        phase.raise_objection(this);

        wr_seq = apb_write_seq::type_id::create("wr_seq");
        wr_seq.addr = 'h300;
        wr_seq.data = 'h12345678;
        wr_seq.start(apb_agt.sqr);

        // Monitor should report slverr=1
        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // APB_SLVERR_TEST_SV
```

- [ ] **Step 2: 运行测试**

```bash
make TEST=apb_slverr_test INJECT_ERROR=1
```

Expected: Test completes, monitor reports PSLVERR=1.

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/test/apb_slverr_test.sv
git commit -m "feat(apb): add slave error response test"
```

---

### Task 18: apb_random_test.sv (APB-F05, F06)

**Files:**
- Create: `vip/amba/apb/test/apb_random_test.sv`

- [ ] **Step 1: 编写 apb_random_test.sv**

```systemverilog
// vip/amba/apb/test/apb_random_test.sv
`ifndef APB_RANDOM_TEST_SV
`define APB_RANDOM_TEST_SV

class apb_random_test extends apb_base_test;
    `uvm_component_utils(apb_random_test)

    task run_phase(uvm_phase phase);
        apb_rw_seq rw_seq;

        phase.raise_objection(this);

        rw_seq = apb_rw_seq::type_id::create("rw_seq");
        rw_seq.num_txns = 50;
        rw_seq.start(apb_agt.sqr);

        #100;
        phase.drop_objection(this);
    endtask
endclass

`endif // APB_RANDOM_TEST_SV
```

- [ ] **Step 2: 运行测试**

```bash
make TEST=apb_random_test
```

Expected: 50 random transactions complete without error.

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/test/apb_random_test.sv
git commit -m "feat(apb): add random read/write test"
```

---

### Task 19: apb_directed_test.sv (APB-F13 Factory Override)

**Files:**
- Create: `vip/amba/apb/test/apb_directed_test.sv`

- [ ] **Step 1: 编写 apb_directed_test.sv**

```systemverilog
// vip/amba/apb/test/apb_directed_test.sv
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
        foreach (int i[4]) begin
            wr_seq = apb_write_seq::type_id::create($sformatf("wr_%0d", i));
            wr_seq.addr = i * 'h4;
            wr_seq.data = i;
            wr_seq.start(apb_agt.sqr);
        end

        // Read back and verify
        foreach (int i[4]) begin
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
```

- [ ] **Step 2: 运行测试**

```bash
make TEST=apb_directed_test
```

Expected: All directed writes read back correctly.

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/test/apb_directed_test.sv
git commit -m "feat(apb): add directed test for factory override"
```

---

## Phase 5: Coverage 和 Scoreboard

### Task 20: apb_coverage.sv

**Files:**
- Create: `vip/amba/apb/src/apb_coverage.sv`

- [ ] **Step 1: 编写 apb_coverage.sv**

```systemverilog
// vip/amba/apb/src/apb_coverage.sv
`ifndef APB_COVERAGE_SV
`define APB_COVERAGE_SV

class apb_coverage extends uvm_subscriber #(apb_transaction);
    `uvm_component_utils(apb_coverage)

    apb_transaction txn;

    covergroup cg_apb;
        cp_write: coverpoint txn.write {
            bins read  = {0};
            bins write = {1};
        }
        cp_slverr: coverpoint txn.slverr {
            bins no_err = {0};
            bins err    = {1};
        }
        cp_idle: coverpoint txn.idle_cycles {
            bins zero = {0};
            bins low  = {[1:2]};
            bins high = {[3:5]};
        }
        cx_write_err: cross cp_write, cp_slverr;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_apb = new();
    endfunction

    function void write(apb_transaction t);
        txn = t;
        cg_apb.sample();
    endfunction
endclass

`endif // APB_COVERAGE_SV
```

- [ ] **Step 2: 更新 apb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/src/apb_coverage.sv vip/amba/apb/src/apb_pkg.sv
git commit -m "feat(apb): add functional coverage"
```

---

### Task 21: apb_scoreboard.sv

**Files:**
- Create: `vip/amba/apb/src/apb_scoreboard.sv`

- [ ] **Step 1: 编写 apb_scoreboard.sv**

```systemverilog
// vip/amba/apb/src/apb_scoreboard.sv
`ifndef APB_SCOREBOARD_SV
`define APB_SCOREBOARD_SV

class apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(apb_scoreboard)

    uvm_analysis_imp #(apb_transaction, apb_scoreboard) ap;

    // Expected memory model
    bit [`APB_DATA_WIDTH-1:0] expected_mem [bit [`APB_ADDR_WIDTH-1:0]];

    int unsigned match_count = 0;
    int unsigned mismatch_count = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void write(apb_transaction t);
        if (t.write) begin
            expected_mem[t.addr] = t.data;
        end else begin
            if (expected_mem.exists(t.addr)) begin
                if (t.data !== expected_mem[t.addr]) begin
                    `uvm_error("SCB", $sformatf("Read mismatch at 0x%08h: expected=0x%08h, actual=0x%08h",
                        t.addr, expected_mem[t.addr], t.data))
                    mismatch_count++;
                end else begin
                    match_count++;
                end
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCB", $sformatf("Matches=%0d, Mismatches=%0d", match_count, mismatch_count), UVM_LOW)
    endfunction
endclass

`endif // APB_SCOREBOARD_SV
```

- [ ] **Step 2: 更新 apb_pkg.sv**

- [ ] **Step 3: Commit**

```bash
git add vip/amba/apb/src/apb_scoreboard.sv vip/amba/apb/src/apb_pkg.sv
git commit -m "feat(apb): add scoreboard with memory model"
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
| APB-F01 | 基本写传输 | smoke_test | Write data 存入 DUT |
| APB-F02 | 基本读传输 | smoke_test | Read data 与 Write 一致 |
| APB-F03 | PREADY=0 等待 | wait_state_test | WAIT_CYCLES>0 时正常完成 |
| APB-F04 | PSLVERR 错误响应 | slverr_test | INJECT_ERROR=1 时 Monitor 报告 slverr |
| APB-F05 | 连续传输 | random_test | 50 笔 back-to-back 传输完成 |
| APB-F06 | Idle cycles | random_test | idle_cycles 随机生效 |
| APB-F10 | PSTRB 字节选通 | pstrb_test | 部分字节写入正确（APB4） |
| APB-F11 | PPROT 保护类型 | pstrb_test | 保护类型正确传递（APB4） |
| APB-F12 | 无 PSTRB 默认行为 | smoke_test | APB3 模式下 strb=全1 |
| APB-F13 | Factory override | directed_test | Override 生效 |
| APB-F14 | Config Object 模式 | 所有测试 | cfg 显式赋值 |

### 运行命令

```bash
# 运行所有测试
cd vip/amba/apb/sim
make TEST=apb_smoke_test
make TEST=apb_random_test
make TEST=apb_wait_state_test WAIT_CYCLES=2
make TEST=apb_slverr_test INJECT_ERROR=1
make TEST=apb_directed_test
```

---

## 开发顺序总结

```
Phase 1 (基础组件):
  Task 1:  目录结构和脚手架
  Task 2:  apb_defines.svh
  Task 3:  apb_interface.sv
  Task 4:  apb_transaction.sv
  Task 5:  apb_config.sv
  Task 6:  apb_sequencer.sv
  Task 7:  apb_monitor.sv
  Task 8:  apb_driver.sv
  Task 9:  apb_slave_driver.sv
  Task 10: apb_agent.sv

Phase 2 (DUT 和 TB):
  Task 11: apb_slave_ram.sv
  Task 12: apb_tb_top.sv
  Task 13: apb_sequences.sv
  Task 14: apb_base_test.sv
  Task 15: apb_smoke_test.sv ← 第一个可运行的测试

Phase 3 (问题修复):
  根据 smoke_test 结果修复问题

Phase 4 (高级测试):
  Task 16: apb_wait_state_test.sv
  Task 17: apb_slverr_test.sv
  Task 18: apb_random_test.sv
  Task 19: apb_directed_test.sv

Phase 5 (Coverage 和 Scoreboard):
  Task 20: apb_coverage.sv
  Task 21: apb_scoreboard.sv
```
