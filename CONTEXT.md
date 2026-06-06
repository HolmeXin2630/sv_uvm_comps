# AMBA VIP 术语表

> 本文件是术语权威定义，设计文档和代码必须与此一致。

---

## 协议层级

### Transaction（传输）

- **APB Transaction**: 单笔传输，包含一个 SETUP + ACCESS 周期
  - 对应 VCS VIP: `svt_apb_transaction`
  - 字段：addr, data, write, idle_cycles, strb, prot, slverr

- **AHB Transaction**: 一个完整 burst，可包含多拍数据
  - 对应 VCS VIP: `svt_ahb_transaction`
  - 字段：xact_type, addr, burst_type, burst_size, data[], prot, hresp
  - **关键语义**: Monitor 等 burst 完成后才 `ap.write(txn)`

### Burst（突发传输）

- **APB**: 无 burst 概念，每笔传输独立
- **AHB**: burst 是原子操作，包含 1-16 拍
  - 类型：SINGLE, INCR, INCR4/8/16, WRAP4/8/16
  - 一个 AHB Transaction = 一个 Burst

### Beat（拍）

- AHB burst 中的单次数据传输
- 一个 beat 包含一个 address phase + 一个 data phase

---

## 组件层级

### Agent

- **APB Agent**: 单一 Agent 类，通过 config 控制 master/slave 角色
- **AHB Agent**: 拆分为 `ahb_master_agent` 和 `ahb_slave_agent`
  - 原因：总线仲裁需要独立控制

### Driver

- **Master Driver**: 主动驱动总线信号
- **Slave Driver**: 被动响应 DUT 请求

### Monitor

- 被动观测总线活动
- 通过 `analysis_port` 广播观测到的 transaction

---

## 配置层级

### Agent Config

- 单个 agent 的配置（active/passive, vif, 宽度等）
- APB: `apb_agent_config`
- AHB: `ahb_agent_config`

### System Config

- 总线环境配置（多 agent 协作）
- APB: `apb_system_config`
- AHB: `ahb_system_config`

---

## 术语约定

| 术语 | 含义 | 禁止替代 |
|------|------|----------|
| transaction | 协议传输单元 | xfer, txn（代码中可用 txn 作为变量名） |
| burst | AHB 突发传输 | - |
| beat | burst 中的单拍 | transfer（易混淆） |
| master | 总线主设备 | manager, host |
| slave | 总线从设备 | subordinate, device |

---

## 宽度控制

### 设计决策

- APB 和 AHB 宽度宏**分开定义**
- 原因：两个 VIP 可以单独使用，SoC 中 APB/AHB 宽度经常不同

### 宏定义

| 宏 | 默认值 | 说明 |
|---|---|---|
| `APB_ADDR_WIDTH` | 32 | APB 地址宽度 |
| `APB_DATA_WIDTH` | 32 | APB 数据宽度 |
| `AHB_ADDR_WIDTH` | 32 | AHB 地址宽度 |
| `AHB_DATA_WIDTH` | 32 | AHB 数据宽度 |

### 使用方式

- 编译时通过 `+define+APB_ADDR_WIDTH=16` 覆盖
- Interface 和 Transaction 共用同一组宏

---

## 协议版本控制

### 设计决策

- 使用**条件编译宏**控制协议版本特性
- 原因：协议版本是编译时确定的，不是运行时配置

### 宏定义

| 宏 | 说明 | 状态 |
|---|---|---|
| `APB_APB4_ENABLE` | 启用 APB4 特性（PSTRB、PPROT） | 可选 |
| `APB_APB5_ENABLE` | 启用 APB5 特性 | 预留 |
| `AHB_AHB5_ENABLE` | 启用 AHB5 特性 | 预留 |

### 版本特性

- **APB3**: 基础特性，不需要 `APB_APB4_ENABLE`
- **APB4**: 可选特性，需要 `APB_APB4_ENABLE`
  - PSTRB：字节选通
  - PPROT：保护类型
- **APB5**: 预留，不实现

---

## 通用设计原则

### VCS VIP 对齐原则

- **所有设计决策优先与 VCS VIP 实现方式对齐**
- 原因：VCS VIP 是工业级实现，经过验证，用户熟悉
- 参考文档：`/mnt/d/Download/FDM/vip_docs_2026.03/vip_docs_2026.03/doc/`

---

## APB Transaction 设计

### 字段定义

| 字段 | 类型 | 说明 | 归属 |
|---|---|---|---|
| `addr` | `bit [ADDR_WIDTH-1:0]` | 地址 | 通用 |
| `data` | `bit [DATA_WIDTH-1:0]` | 数据 | 通用 |
| `write` | `bit` | 1=写, 0=读 | 通用 |
| `idle_cycles` | `int unsigned` | 传输前 idle 拍数 | **Master 专用** |
| `strb` | `bit [DATA_WIDTH/8-1:0]` | 字节选通 | APB4 可选 |
| `prot` | `bit [2:0]` | 保护类型 | APB4 可选 |
| `slverr` | `bit` | Slave 错误响应 | 响应字段 |

### 设计决策

- `idle_cycles` 是 **Master 专用**字段
  - Master Driver：先等 `idle_cycles` 拍，再驱动传输
  - Slave Driver：不处理 `idle_cycles`
  - Monitor：记录实际观测到的 idle，不依赖 `idle_cycles`
- `strb` 和 `prot` 通过 `APB_APB4_ENABLE` 条件编译
- `slverr` 由 Slave Driver 或 Monitor 填充

---

## APB Agent 架构

### 设计决策

- APB 单一 Agent 类，通过 config 控制 master/slave 角色
- APB Slave Agent 采用与 AHB Slave Agent 相同的架构：Monitor 检测，Driver 响应，Sequencer 中转

### APB Slave Agent 数据流

```
┌─────────────────────────────────────────────────────────┐
│                    APB Slave Agent                      │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │ Slave       │    │ Slave       │    │ Slave       │ │
│  │ Monitor     │───→│ Sequencer   │◄───│ Driver      │ │
│  └─────────────┘    └─────────────┘    └─────────────┘ │
│         │                  ▲                  │         │
│         │                  │                  │         │
│         ▼                  │                  ▼         │
│    analysis_port      seq_item_port      vif (总线)    │
└─────────────────────────────────────────────────────────┘
```

### APB Slave Agent 工作流程

1. **Slave Monitor**：检测总线活动，发现有效传输
   - 检测 SETUP（PSEL=1, PENABLE=0）→ 采样地址
   - 检测 ACCESS（PSEL=1, PENABLE=1）→ 采样数据
   - 通过 `analysis_port` 发送请求到 Sequencer

2. **Slave Sequencer**：中转请求到 Driver

3. **Slave Driver**：从 Sequencer 获取响应，驱动总线
   - 驱动 PRDATA、PREADY、PSLVERR
   - 支持 wait state（PREADY=0）
   - 支持错误注入（PSLVERR=1）

---

## AHB Agent 架构

### 设计决策

- AHB 拆分为 `ahb_master_agent` 和 `ahb_slave_agent`
- 原因：总线仲裁需要独立控制 master/slave

### AHB Slave Agent Monitor → Sequence 通知机制

**与 VCS VIP 一致**：AHB Slave Agent 采用 Monitor → Sequencer FIFO → Sequence → Driver 架构

```systemverilog
// ahb_slave_agent.sv
function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Monitor → Sequencer FIFO（传递 DUT 请求）
    mon.ap.connect(sqr.request_fifo.analysis_export);
    // Driver ← Sequencer（标准连接）
    drv.seq_item_port.connect(sqr.seq_item_export);
endfunction
```

### AHB Slave Agent 数据流

```
DUT 发起传输 → Slave Monitor 观测 → ap.write(txn)
    → sqr.request_fifo → Slave Sequence: get(req)
    → 生成响应 → start_item/finish_item → Slave Driver 驱动回 DUT
```

### AHB Slave Sequencer 声明

```systemverilog
class ahb_slave_sequencer extends uvm_sequencer #(ahb_transaction);
    uvm_tlm_analysis_fifo #(ahb_transaction) request_fifo;
    // ...
endclass
```

### AHB Slave Sequence 从 FIFO 获取 DUT 请求

```systemverilog
task body();
    forever begin
        p_sequencer.request_fifo.get(req_txn);  // 阻塞等待
        // 查内存模型，生成响应...
        start_item(rsp_txn);
        finish_item(rsp_txn);
    end
endtask
```

---

## AHB Master Driver Pipeline 设计

### 设计决策

- 采用**双线程**实现 pipeline（参照 UVM Cookbook）
- 原因：AHB 协议支持 address phase 和 data phase 重叠

### 实现方案

```systemverilog
task run_phase(uvm_phase phase);
    fork
        address_thread();  // 驱动 address phase
        data_thread();     // 驱动 data phase
    join
endtask

task address_thread();
    forever begin
        // 从 Sequencer 获取 transaction
        seq_item_port.get(txn);
        // 驱动 address phase
        vif.HADDR  = txn.addr;
        vif.HTRANS = txn.xact_type;
        vif.HSIZE  = txn.burst_size;
        vif.HBURST = txn.burst_type;
        // 等待 HREADY（address phase 完成）
        @(posedge vif.HCLK);
        while (!vif.HREADY) @(posedge vif.HCLK);
    end
endtask

task data_thread();
    forever begin
        // 等待 address phase 完成
        // 驱动 data phase
        if (txn.xact_type == WRITE)
            vif.HWDATA = txn.data[beat];
        else
            txn.data[beat] = vif.HRDATA;
        // 等待 HREADY（data phase 完成）
        @(posedge vif.HCLK);
        while (!vif.HREADY) @(posedge vif.HCLK);
    end
endtask
```

### AHB 协议时序

```
        ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐
CLK     │   │   │   │   │   │   │   │   │   │
        └───┘   └───┘   └───┘   └───┘   └───┘
            ┌───────┐   ┌───────┐
HTRANS      │ NONSEQ│   │ NONSEQ│
        ────┘       └───┘       └───────────
            ┌───────┐   ┌───────┐
HADDR       │ Addr1 │   │ Addr2 │
        ────┘       └───┘       └───────────
                    ┌───────┐   ┌───────┐
HWDATA              │ Data1 │   │ Data2 │
        ────────────┘       └───┘       └───
            ┌───────┐   ┌───────┐   ┌───────┐
HREADY      │       │   │       │   │       │
        ────┘       └───┘       └───┘       └───
```

### 关键点

- **Address thread**：驱动 HADDR/HTRANS/HSIZE/HBURST，等待 HREADY
- **Data thread**：驱动 HWDATA（写）或采样 HRDATA（读），等待 HREADY
- **Pipeline 重叠**：Address thread 和 Data thread 可以同时工作

---

## AHB Slave Driver 设计

### 设计决策

- 检测有效传输（NONSEQ/SEQ）→ 从 sequencer 获取响应
- 插入 wait states（HREADY=0）→ 驱动 HREADY=1 + HRDATA/HRESP

### 实现方案

```systemverilog
task run_phase(uvm_phase phase);
    forever begin
        // 1. 等待有效传输
        @(posedge vif.HCLK);
        while (!(vif.HTRANS inside {NONSEQ, SEQ} && vif.HREADY))
            @(posedge vif.HCLK);
        
        // 2. 从 Sequencer 获取响应
        seq_item_port.get(rsp);
        
        // 3. 插入 wait states
        repeat (rsp.num_wait_cycles[beat]) begin
            vif.HREADY = 1'b0;
            @(posedge vif.HCLK);
        end
        
        // 4. 驱动响应
        vif.HREADY = 1'b1;
        vif.HRDATA = rsp.data[beat];
        vif.HRESP  = rsp.hresp;
    end
endtask
```

### AHB HTRANS 编码

| HTRANS | 含义 | 说明 |
|--------|------|------|
| IDLE | 空闲 | 无有效传输 |
| BUSY | 忙 | Master 暂停 burst |
| NONSEQ | 非连续 | burst 第一拍或单笔传输 |
| SEQ | 连续 | burst 后续拍 |

### 关键点

- 检测 HTRANS == NONSEQ 或 SEQ，且 HREADY == 1
- 从 Sequencer 获取响应后，插入 wait states
- 最后驱动 HREADY=1 + HRDATA/HRESP

---

## AHB Monitor 设计

### 设计决策

- 检测 burst 起始（NONSEQ + HREADY=1）→ 记录地址/控制信号
- 循环采样每拍数据直到 burst 完成 → `ap.write(txn)`

### 实现方案

```systemverilog
task run_phase(uvm_phase phase);
    forever begin
        // 1. 等待 burst 起始
        @(posedge vif.HCLK);
        while (!(vif.HTRANS == NONSEQ && vif.HREADY))
            @(posedge vif.HCLK);
        
        // 2. 记录起始信息
        txn = apb_transaction::type_id::create("txn");
        txn.addr       = vif.HADDR;
        txn.burst_type = vif.HBURST;
        txn.burst_size = vif.HSIZE;
        txn.prot       = vif.HPROT;
        
        // 3. 计算 burst 长度
        burst_length = get_burst_length(txn.burst_type);
        
        // 4. 循环采样每拍数据
        for (int i = 0; i < burst_length; i++) begin
            // 等待 HREADY（数据有效）
            @(posedge vif.HCLK);
            while (!vif.HREADY) @(posedge vif.HCLK);
            
            // 采样数据
            if (txn.xact_type == READ)
                txn.data[i] = vif.HRDATA;
            else
                txn.data[i] = vif.HWDATA;
            
            // 采样响应
            txn.hresp = vif.HRESP;
        end
        
        // 5. 发送 transaction
        ap.write(txn);
    end
endtask

function int get_burst_length(hburst_e burst_type);
    case (burst_type)
        SINGLE:  return 1;
        INCR:    return 16;  // 最大 16 拍，实际由 HTRANS 决定
        INCR4:   return 4;
        INCR8:   return 8;
        INCR16:  return 16;
        WRAP4:   return 4;
        WRAP8:   return 8;
        WRAP16:  return 16;
        default: return 1;
    endcase
endfunction
```

### AHB Burst 类型

| Burst 类型 | 拍数 | 结束条件 |
|------------|------|----------|
| SINGLE | 1 | 固定 1 拍 |
| INCR | 1-16 | 遇到 NONSEQ/IDLE |
| INCR4/8/16 | 4/8/16 | 固定拍数 |
| WRAP4/8/16 | 4/8/16 | 固定拍数 |

### 关键点

- 检测 HTRANS == NONSEQ && HREADY == 1 作为 burst 起始
- 根据 burst_type 计算 burst 长度
- 循环采样每拍数据，等待 HREADY
- 对于 INCR（不定长 burst），需要检测下一个 NONSEQ/IDLE 来判断结束

---

## Sequence 库设计

### 设计决策

- 遵循 `uvm_coding_guidelines.md`，使用 `start_item` / `finish_item`，不用 `uvm_do_with`
- APB 和 AHB 各有独立的 Sequence 库

### APB Sequences

| Sequence | 说明 |
|----------|------|
| `apb_write_seq` | 单笔写 |
| `apb_read_seq` | 单笔读，从 response 获取数据 |
| `apb_rw_seq` | 连续随机读写 |

### AHB Sequences

| Sequence | 说明 |
|----------|------|
| `ahb_single_write_seq` | 单笔 SINGLE 写 |
| `ahb_single_read_seq` | 单笔 SINGLE 读 |
| `ahb_burst_write_seq` | Burst 写（INCR4/WRAP8 等） |
| `ahb_random_rw_seq` | 随机读写 |
| `ahb_slave_response_seq` | Slave 响应（forever 循环） |

### 实现示例

```systemverilog
// APB Write Sequence
class apb_write_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_write_seq)
    
    bit [ADDR_WIDTH-1:0] addr;
    bit [DATA_WIDTH-1:0] data;
    
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

// AHB Slave Response Sequence
class ahb_slave_response_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_slave_response_seq)
    
    task body();
        ahb_transaction txn;
        forever begin
            p_sequencer.request_fifo.get(txn);  // 阻塞等待
            // 生成响应
            rsp = ahb_transaction::type_id::create("rsp");
            start_item(rsp);
            assert(rsp.randomize()) else `uvm_fatal("RANDFAIL", "Randomize failed")
            finish_item(rsp);
        end
    endtask
endclass
```

### 关键点

- 使用 `start_item` / `finish_item`，不用 `uvm_do_with`
- 每次 `randomize` 检查返回值
- Slave Response Sequence 使用 `forever` 循环，从 FIFO 获取请求

---

## Testbench 结构

### 设计决策

- tb_top 为 module，包含 clock/reset 生成、Interface 例化、DUT 例化、config_db 设置
- DUT 模型为简单 Slave RAM，支持基本读写

### Testbench 架构

```
tb_top (module)
├── clock/reset 生成
├── Interface 例化
├── DUT 例化（简单 slave RAM 或 master 模型）
├── config_db 设置（vif → agent_config → agent）
└── run_test()
```

### DUT 模型

| 协议 | DUT 模型 | 说明 |
|------|----------|------|
| APB | APB Slave RAM | 简单内存模型，接收读写，返回数据 |
| AHB | AHB Slave RAM | 简单内存模型，支持 burst 读写 |
| AHB | AHB Master DUT（可选） | 用于验证 Slave Agent |

### APB Slave RAM 实现

```systemverilog
module apb_slave_ram (
    input  logic        PCLK,
    input  logic        PRESETn,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PADDR,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR
);
    logic [31:0] mem [0:1023];
    
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PREADY  <= 1'b1;
            PSLVERR <= 1'b0;
            PRDATA  <= '0;
        end else if (PSEL && PENABLE) begin
            PREADY <= 1'b1;
            if (PWRITE)
                mem[PADDR[11:2]] <= PWDATA;
            else
                PRDATA <= mem[PADDR[11:2]];
        end
    end
endmodule
```

### AHB Slave RAM 实现

```systemverilog
module ahb_slave_ram (
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic        HSEL,
    input  logic [1:0]  HTRANS,
    input  logic        HWRITE,
    input  logic [2:0]  HSIZE,
    input  logic [2:0]  HBURST,
    input  logic [31:0] HADDR,
    input  logic [31:0] HWDATA,
    output logic [31:0] HRDATA,
    output logic        HREADY,
    output logic [1:0]  HRESP
);
    logic [31:0] mem [0:1023];
    
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HREADY <= 1'b1;
            HRESP  <= 2'b00;  // OKAY
            HRDATA <= '0;
        end else if (HSEL && HTRANS inside {NONSEQ, SEQ}) begin
            HREADY <= 1'b1;
            if (HWRITE)
                mem[HADDR[11:2]] <= HWDATA;
            else
                HRDATA <= mem[HADDR[11:2]];
        end
    end
endmodule
```

### 关键点

- DUT 模型为简单 Slave RAM，不实现复杂协议特性
- 通过 config_db 传递 vif → agent_config → agent
- tb_top 通过 `+incdir+../src` 包含 src 目录

---

## Makefile 设计

### 设计决策

- APB 和 AHB 各有独立 Makefile
- 原因：APB 和 AHB 是独立的 VIP，可以单独使用

### 目录结构

```
vip/amba/
├── apb/
│   ├── src/
│   ├── tb/
│   ├── test/
│   └── sim/
│       ├── Makefile        ← APB 独立 Makefile
│       └── .gitignore
└── ahb/
    ├── src/
    ├── tb/
    ├── test/
    └── sim/
        ├── Makefile        ← AHB 独立 Makefile
        └── .gitignore
```

### Makefile 模板

```makefile
# 环境变量（避免硬编码路径）
SIM_OUTPUT ?= $(CURDIR)/output
VCS_HOME   ?= $(VCS_HOME)

# 编译选项
COMPILE_OPTS = -sverilog -full64 -timescale=1ns/1ps
COMPILE_OPTS += +define+UVM_PACKER_MAX_BYTES=1500000
COMPILE_OPTS += +define+UVM_DISABLE_AUTO_ITEM_RECORDING
COMPILE_OPTS += +incdir+../src

# 支持多种测试
TEST ?= apb_smoke_test

# 支持覆盖率
COVERAGE_OPTS = -cm line+cond+fsm+tgl
COVERAGE_OPTS += -cm_dir $(SIM_OUTPUT)/coverage

# 支持波形
WAVE_OPTS = +define+WAVE_DUMP

# 目标
all: comp run

comp:
	vcs $(COMPILE_OPTS) $(COVERAGE_OPTS) $(WAVE_OPTS) -o $(SIM_OUTPUT)/simv $(TB_TOP)

run:
	$(SIM_OUTPUT)/simv +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=UVM_MEDIUM $(COVERAGE_OPTS)

cov:
	urg -dir $(SIM_OUTPUT)/coverage.vdb -report $(SIM_OUTPUT)/coverage_report

clean:
	rm -rf $(SIM_OUTPUT) csrc *.log *.key *.vpd *.vdb
```

### 关键点

- 环境变量避免硬编码路径
- 支持覆盖率收集
- 支持波形 dump
- 支持多种测试通过 `TEST` 变量

---

## TDD 开发流程

### 设计决策

- 采用 TDD（测试驱动开发）流程
- 与 `features_checklist.md` 结合，每个 feature 对应至少一个测试

### 流程步骤

```
1. 从 features_checklist.md 选择下一个 feature（如 APB-F01）
2. 编写对应的测试（如 apb_smoke_test）
3. 编写最小实现，让测试通过
4. 在 features_checklist.md 中打勾（APB-F01 ✅）
5. 重构代码，保持测试通过
6. 重复下一个 feature
```

### 示例

```
features_checklist.md:
- [ ] APB-F01 基本写传输 — apb_smoke_test
- [ ] APB-F02 基本读传输 — apb_smoke_test

执行：
1. 编写 apb_smoke_test（测试 APB-F01 和 APB-F02）
2. 编写 apb_driver、apb_monitor、apb_slave_ram
3. 运行测试，确保通过
4. 更新 features_checklist.md：
   - [x] APB-F01 基本写传输 — apb_smoke_test
   - [x] APB-F02 基本读传输 — apb_smoke_test
5. 重构代码
6. 继续下一个 feature
```

### 关键点

- 每个 feature 对应至少一个测试
- 测试通过后，在 features_checklist.md 中打勾
- 重构时保持所有测试通过
- 每个 VIP 开发前，先输出 `features.md` 文档，确认后再开发

---

## 文件清单

### 设计决策

- 按照开发顺序组织文件
- 源码、TB、测试、构建分开存放
- 每个 VIP 独立目录

### Phase 1：APB VIP

**源码（src/）- 13 个文件：**
1. `apb_defines.svh`
2. `apb_interface.sv`
3. `apb_transaction.sv`
4. `apb_config.sv`
5. `apb_sequencer.sv`
6. `apb_monitor.sv`
7. `apb_driver.sv`
8. `apb_slave_driver.sv`
9. `apb_agent.sv`
10. `apb_sequences.sv`
11. `apb_coverage.sv`
12. `apb_scoreboard.sv`
13. `apb_pkg.sv`

**TB（tb/）- 3 个文件：**
14. `apb_slave_ram.sv`（DUT 模型）
15. `apb_tb_top.sv`
16. `apb_tb_pkg.sv`

**测试（test/）- 9 个文件：**
17. `apb_base_test.sv` → 基础 env 配置
18. `apb_smoke_test.sv` → APB-F01, F02, F09, F12
19. `apb_random_test.sv` → APB-F05, F06
20. `apb_directed_test.sv` → APB-F13
21. `apb_wait_state_test.sv` → APB-F03
22. `apb_slverr_test.sv` → APB-F04
23. `apb_pstrb_test.sv` → APB-F10, F11
24. `apb_slave_agent_test.sv` → APB-F07
25. `apb_multi_slave_test.sv` → APB-F08

**构建（sim/）- 2 个文件：**
26. `Makefile`
27. `.gitignore`

### Phase 2：AHB VIP

**源码（src/）- 15 个文件：**
1. `ahb_defines.svh`
2. `ahb_interface.sv`
3. `ahb_transaction.sv`
4. `ahb_config.sv`
5. `ahb_sequencer.sv`
6. `ahb_monitor.sv`
7. `ahb_master_driver.sv`
8. `ahb_slave_driver.sv`
9. `ahb_master_agent.sv`
10. `ahb_slave_agent.sv`（含 Monitor→Sequence FIFO）
11. `ahb_bus_env.sv`
12. `ahb_sequences.sv`
13. `ahb_coverage.sv`
14. `ahb_scoreboard.sv`
15. `ahb_pkg.sv`

**TB（tb/）- 3 个文件：**
16. `ahb_slave_ram.sv`（DUT 模型）
17. `ahb_tb_top.sv`
18. `ahb_tb_pkg.sv`

**测试（test/）- 11 个文件：**
19. `ahb_base_test.sv` → 基础 env 配置
20. `ahb_lite_test.sv` → AHB-F14, F20
21. `ahb_burst_test.sv` → AHB-F02, F03, F04, F18
22. `ahb_pipeline_test.sv` → AHB-F11
23. `ahb_slave_test.sv` → AHB-F12, F13
24. `ahb_wait_state_test.sv` → AHB-F05
25. `ahb_error_resp_test.sv` → AHB-F06
26. `ahb_mastlock_test.sv` → AHB-F07
27. `ahb_burst_size_test.sv` → AHB-F01, F08
28. `ahb_busy_test.sv` → AHB-F09
29. `ahb_full_bus_test.sv` → AHB-F15, F16, F17, F19

**构建（sim/）- 2 个文件：**
30. `Makefile`
31. `.gitignore`

### 关键点

- 源码按照依赖关系排序，确保编译顺序正确
- TB 按照依赖关系排序，确保编译顺序正确
- 测试按照 feature 依赖排序，确保测试覆盖完整
- 构建最后创建，确保 Makefile 包含所有文件

---

## AHB Transaction 设计

### 字段定义

| 字段 | 类型 | 说明 | 归属 |
|---|---|---|---|
| `xact_type` | `xact_type_e` | READ / WRITE | 通用 |
| `addr` | `bit [ADDR_WIDTH-1:0]` | 起始地址 | 通用 |
| `burst_type` | `hburst_e` | SINGLE/INCR/WRAP4/INCR4/... | 通用 |
| `burst_size` | `hsize_e` | 8/16/32/64/... bit | 通用 |
| `data[]` | `bit [DATA_WIDTH-1:0]` | burst 数据队列 | 通用 |
| `prot` | `bit [3:0]` | 保护类型 | 通用 |
| `hresp` | `hresp_e` | 响应（OKAY/ERROR） | 响应字段 |
| `num_wait_cycles[]` | `int unsigned` | 每拍等待周期 | **Slave 专用** |

### 设计决策

- `num_wait_cycles[]` 是 **Slave 专用**字段
  - Slave Driver：每拍前先等 `num_wait_cycles[i]` 拍，再驱动数据
  - Master Driver：不处理 `num_wait_cycles[]`
  - Monitor：记录实际观测到的 wait state，不依赖 `num_wait_cycles[]`
- `data[]` 队列长度由 `burst_type` 自动约束
- `num_wait_cycles[]` 队列长度 == `data[]` 队列长度

### 关键方法

- `get_burst_length()` — 返回 burst 拍数
- `get_transfer_size()` — 返回单次传输字节数
- `get_beat_addr(int beat)` — 返回第 N 拍地址（支持 WRAP 计算）

---

## 命名规范

### Package 前缀

- 前缀：`hx_`（HolmeXin 个人标识）
- 示例：`hx_apb_pkg`, `hx_ahb_pkg`
- 与 VCS VIP（`svt_*`）区分
- 使用方式：`import hx_apb_pkg::*;`

### 内部类名

- Package 内部类名不加前缀
- 示例：`apb_transaction`, `ahb_driver`
- 通过 package 限定访问：`hx_apb_pkg::apb_transaction`

---

## 参考

- VCS VIP: `svt_apb_transaction`, `svt_ahb_transaction`
- 设计文档: `docs/superpowers/specs/2026-06-06-amba-vip-design.md`
