# AMBA VIP 术语表

> 本文件是术语权威定义，设计文档和代码必须与此一致。

---

## 协议层级

### Transaction（传输）

- **APB Transaction**: 单笔传输，包含一个 SETUP + ACCESS 周期
  - 对应 VCS VIP: `svt_apb_transaction`
  - 字段：addr, data, write, idle_cycles, strb, prot, slverr

- **AHB Transaction**: 单拍传输（Beat-level），遵循 UVM Cookbook 推荐
  - 对应 VCS VIP: `svt_ahb_transaction`（注：粒度不同，UVM Cookbook 推荐 beat-level）
  - 字段：xact_type, addr, burst_type, burst_size, data, prot, hresp, wait_cycles
  - **关键语义**: 每拍一个 transaction，由 Sequence 组织 burst

### Burst（突发传输）

- **APB**: 无 burst 概念，每笔传输独立
- **AHB**: burst 由 1-16 个 Beat-level Transaction 组成
  - 类型：SINGLE, INCR, INCR4/8/16, WRAP4/8/16
  - **设计决策**: Sequence 负责 burst 管理，Driver 只处理单拍

### Beat（拍）

- AHB burst 中的单次数据传输
- 一个 beat = 一个 AHB Transaction
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

- **参考 VCS VIP 实现，但优先遵循 UVM Cookbook**
- 原因：VCS VIP 是工业级实现，但 UVM Cookbook 是 UVM 最佳实践
- 参考文档：`/mnt/d/Download/FDM/vip_docs_2026.03/vip_docs_2026.03/doc/`

### 设计决策优先级

1. **UVM Cookbook** — UVM 最佳实践，pipelined bus 使用 beat-level transaction
2. **VCS VIP** — 工业级实现参考，但 burst-level 设计增加 Driver 复杂度
3. **项目需求** — 简单、可维护、易于调试

**AHB Transaction 粒度决策**：选择 Beat-level（遵循 UVM Cookbook），而非 Burst-level（VCS VIP 方式）

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

### AHB Master Agent 连接

**设计决策**：标准 UVM 连接，Monitor 的 analysis_port 由外部连接，vif 在 build_phase 中获取

```systemverilog
// ahb_master_agent.sv
class ahb_master_agent extends uvm_agent;
    `uvm_component_utils(ahb_master_agent)
    
    // 暴露给用户的 API
    ahb_agent_config cfg;
    ahb_sequencer    sqr;
    
    // 内部组件
    ahb_master_driver drv;
    ahb_monitor       mon;
    
    // vif
    virtual ahb_interface vif;
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // 从 config_db 获取 vif（在 agt 的 build_phase 中）
        if (!uvm_config_db#(virtual ahb_interface)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", $sformatf("vif not set for %s", get_full_name()))
        
        // 创建组件
        if (cfg.active) begin
            drv = ahb_master_driver::type_id::create("drv", this);
            sqr = ahb_sequencer::type_id::create("sqr", this);
        end
        mon = ahb_monitor::type_id::create("mon", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // 传递 vif 给 driver 和 monitor
        drv.vif = vif;
        mon.vif = vif;
        
        // 标准 UVM 连接
        if (cfg.active)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
```

### AHB Master Agent 数据流

```
Sequence → Sequencer → Master Driver → 总线信号
                         ↓
                    Monitor 观测 → beat_ap / burst_ap
```

### AHB Slave Agent Monitor → Sequence 通知机制

**连接 `beat_ap`**：Slave 逐拍响应，可以插入 wait states 或提前返回 ERROR

```systemverilog
// ahb_slave_agent.sv
function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Monitor beat_ap → Sequencer FIFO（逐拍传递 DUT 请求）
    mon.beat_ap.connect(sqr.request_fifo.analysis_export);
    // Driver ← Sequencer（标准连接）
    drv.seq_item_port.connect(sqr.seq_item_export);
endfunction
```

### AHB Slave Agent 数据流

```
DUT 发起传输 → Slave Monitor 观测 → beat_ap.write(txn)  [逐拍]
    → sqr.request_fifo → Slave Sequence: get(req)  [逐拍获取]
    → 生成响应 → start_item/finish_item → Slave Driver 驱动回 DUT  [逐拍响应]
```

### 设计要点

- **逐拍响应**：Slave Sequence 每拍收到一个请求（`data[]` 长度 1），每拍生成一个响应
- **灵活控制**：Slave Sequence 可以根据需要插入 wait states 或提前返回 ERROR
- **burst 上下文**：Slave Sequence 从 `burst_type` 字段推断 burst 长度

### AHB Slave Sequencer 声明

```systemverilog
class ahb_slave_sequencer extends uvm_sequencer #(ahb_transaction);
    uvm_tlm_analysis_fifo #(ahb_transaction) request_fifo;
    // ...
endclass
```

### AHB Slave Sequence 从 FIFO 获取 DUT 请求

**设计决策**：Slave Sequence 从 transaction 的上下文字段获取 burst 信息

```systemverilog
class ahb_slave_response_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_slave_response_seq)
    
    // 内存模型
    bit [DATA_WIDTH-1:0] mem [bit [ADDR_WIDTH-1:0]];
    
    task body();
        ahb_transaction req, rsp;
        forever begin
            // 从 Monitor beat_ap 获取请求（逐拍）
            p_sequencer.request_fifo.get(req);
            
            // 从 transaction 字段获取 burst 上下文
            // req.burst_type   — burst 类型（SINGLE/INCR/WRAP4...）
            // req.is_first_beat — 是否首拍
            // req.burst_length — burst 总拍数
            // req.beat_num     — 当前第几拍
            
            // 生成响应
            rsp = ahb_transaction::type_id::create("rsp");
            start_item(rsp);
            assert(rsp.randomize() with {
                rsp.xact_type   == req.xact_type;
                rsp.addr        == req.addr;
                rsp.burst_type  == req.burst_type;
                rsp.burst_size  == req.burst_size;
                rsp.hresp       == OKAY;
                rsp.wait_cycles == 0;  // 或随机等待
            }) else `uvm_fatal("RANDFAIL", "Randomize failed")
            
            // 读操作：从内存模型获取数据
            if (req.xact_type == READ)
                rsp.data = new[1](mem.exists(req.addr) ? mem[req.addr] : '0);
            
            // 写操作：更新内存模型
            if (req.xact_type == WRITE)
                mem[req.addr] = req.data[0];
            
            finish_item(rsp);
        end
    endtask
endclass
```

### Slave Sequence 上下文使用示例

```systemverilog
// 示例：根据 burst 类型插入不同的 wait states
task body();
    forever begin
        p_sequencer.request_fifo.get(req);
        
        rsp = ahb_transaction::type_id::create("rsp");
        start_item(rsp);
        
        // 首拍插入更多 wait state（模拟慢速设备）
        if (req.is_first_beat)
            assert(rsp.randomize() with { rsp.wait_cycles inside {[2:4]}; })
        else
            assert(rsp.randomize() with { rsp.wait_cycles == 0; })
        
        finish_item(rsp);
    end
endtask
```

---

## AHB Master Driver Pipeline 设计

### 设计决策

- 采用**双线程**实现 pipeline（遵循 UVM Cookbook）
- **Beat-level Transaction**: 每个 transaction 代表一拍，Driver 无需内部拆分
- Pipeline 天然支持：address_thread 和 data_thread 直接处理单拍

### 实现方案

```systemverilog
class ahb_master_driver extends uvm_driver #(ahb_transaction);
    `uvm_component_utils(ahb_master_driver)
    
    virtual ahb_interface.master_cb vif;
    
    // Pipeline 同步 mailbox
    mailbox #(ahb_transaction) addr_done_mb;  // address phase 完成通知
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        addr_done_mb = new();
    endfunction
    
    task run_phase(uvm_phase phase);
        fork
            address_thread();  // 驱动 address phase
            data_thread();     // 驱动 data phase
        join
    endtask
    
    task address_thread();
        ahb_transaction txn;
        forever begin
            // 从 Sequencer 获取单拍 transaction
            seq_item_port.get(txn);
            
            // 驱动 address phase
            @(vif.master_cb);
            vif.master_cb.HADDR   <= txn.addr;
            vif.master_cb.HTRANS  <= txn.is_first_beat ? txn.burst_type : SEQ;
            vif.master_cb.HSIZE   <= txn.burst_size;
            vif.master_cb.HBURST  <= txn.burst_type;
            vif.master_cb.HWRITE  <= txn.xact_type;
            vif.master_cb.HPROT   <= txn.prot;
            
            // 等待 HREADY（address phase 完成）
            while (!vif.master_cb.HREADY) @(vif.master_cb);
            
            // 通知 data thread
            addr_done_mb.put(txn);
        end
    endtask
    
    task data_thread();
        ahb_transaction txn;
        forever begin
            // 等待 address phase 完成
            addr_done_mb.get(txn);
            
            // 写操作：驱动 HWDATA
            if (txn.xact_type == WRITE) begin
                @(vif.master_cb);
                vif.master_cb.HWDATA <= txn.data;
            end
            
            // 等待 HREADY（data phase 完成）
            while (!vif.master_cb.HREADY) @(vif.master_cb);
            
            // 读操作：采样 HRDATA
            if (txn.xact_type == READ) begin
                txn.data = vif.master_cb.HRDATA;
            end
            
            // 采样响应
            txn.hresp = vif.master_cb.HRESP;
            
            // 发送响应给 sequencer（可选，用于 response 机制）
            seq_item_port.put(txn);
        end
    endtask
endclass
```

### Sequence 发送 Burst

```systemverilog
class ahb_burst_write_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_burst_write_seq)
    
    bit [ADDR_WIDTH-1:0] start_addr;
    hburst_e             burst_type = INCR4;
    bit [DATA_WIDTH-1:0] burst_data[];
    
    task body();
        ahb_transaction txn;
        int burst_len = get_burst_length(burst_type);
        
        for (int i = 0; i < burst_len; i++) begin
            txn = ahb_transaction::type_id::create($sformatf("txn_%0d", i));
            start_item(txn);
            assert(txn.randomize() with {
                txn.xact_type     == WRITE;
                txn.addr          == get_beat_addr(start_addr, burst_type, i);
                txn.burst_type    == local::burst_type;
                txn.burst_size    == WORD;
                txn.data          == burst_data[i];
                txn.beat_num      == i;
                txn.burst_length  == local::burst_len;
                txn.is_first_beat == (i == 0);
                txn.is_last_beat  == (i == burst_len - 1);
            }) else `uvm_fatal("RANDFAIL", "Randomize failed")
            finish_item(txn);
        end
    endtask
    
    // 地址计算（支持 WRAP）
    function bit [ADDR_WIDTH-1:0] get_beat_addr(
        bit [ADDR_WIDTH-1:0] base_addr,
        hburst_e burst_type,
        int beat_num
    );
        int burst_len = get_burst_length(burst_type);
        int transfer_size = 4;  // 假设 32-bit，实际由 burst_size 决定
        bit [ADDR_WIDTH-1:0] aligned_addr;
        int wrap_boundary;
        
        aligned_addr = (base_addr / (burst_len * transfer_size)) * (burst_len * transfer_size);
        
        case (burst_type)
            WRAP4, WRAP8, WRAP16: begin
                wrap_boundary = burst_len * transfer_size;
                return aligned_addr + ((base_addr - aligned_addr + beat_num * transfer_size) % wrap_boundary);
            end
            default: begin
                return base_addr + beat_num * transfer_size;
            end
        endcase
    endfunction
endclass
```

### AHB 协议时序（Beat-level Transaction）

```
Sequence 发送:    txn1(addr=A1)  txn2(addr=A2)  txn3(addr=A3)  txn4(addr=A4)
                  ↓              ↓              ↓              ↓
address_thread:   [get txn1]     [get txn2]     [get txn3]     [get txn4]
                  [drive A1]     [drive A2]     [drive A3]     [drive A4]
                         ↓              ↓              ↓
data_thread:            [drive D1]     [drive D2]     [drive D3]

时钟:           1      2      3      4      5
                ┌────┐┌────┐┌────┐┌────┐┌────┐
CLK:            │    ││    ││    ││    ││    │
                └────┘└────┘└────┘└────┘└────┘
                ┌────────┐┌────────┐
HTRANS:         │ NONSEQ ││  SEQ   │   ← 首拍 NONSEQ，后续 SEQ
                └────────┘└────────┘
                ┌────────┐┌────────┐
HADDR:          │  A1    ││  A2    │   ← 每拍一个地址
                └────────┘└────────┘
                         ┌────────┐┌────────┐
HWDATA:                 │  D1    ││  D2    │   ← 每拍一个数据
                         └────────┘└────────┘
                ┌────────┐┌────────┐┌────────┐
HREADY:         │   1    ││   1    ││   1    │   ← 正常无等待
                └────────┘└────────┘└────────┘
```

### 关键点

- **Beat-level Transaction**: 每拍一个 transaction，Driver 无需内部拆分
- **Address thread**: 驱动 HADDR/HTRANS/HSIZE/HBURST，等待 HREADY
- **Data thread**: 驱动 HWDATA（写）或采样 HRDATA（读），等待 HREADY
- **Pipeline 重叠**: Address thread 和 Data thread 通过 mailbox 同步，可以同时工作
- **Sequence 管理 burst**: Sequence 负责循环发送 beat，计算每拍地址

---

## AHB Slave Driver 设计

### 设计决策

- **Beat-level Transaction**: 每拍一个 transaction，从 Sequencer 获取
- **先检测，再获取**：先检测有效传输，再从 Sequencer 获取响应
- **灵活响应**：支持插入 wait states 和错误注入

### run_phase 逻辑

```
1. 等待有效传输（HTRANS == NONSEQ/SEQ && HREADY == 1）
2. 从 Sequencer 获取响应
3. 插入 wait states（如果 wait_cycles > 0）
4. 驱动响应（HRDATA/HRESP）
```

### 实现方案

```systemverilog
class ahb_slave_driver extends uvm_driver #(ahb_transaction);
    `uvm_component_utils(ahb_slave_driver)
    
    virtual ahb_interface.slave_cb vif;
    
    task run_phase(uvm_phase phase);
        ahb_transaction rsp;
        
        forever begin
            // 1. 等待有效传输
            @(vif.slave_cb);
            while (!(vif.slave_cb.HTRANS inside {NONSEQ, SEQ} && vif.slave_cb.HREADY))
                @(vif.slave_cb);
            
            // 2. 从 Sequencer 获取响应（单拍）
            seq_item_port.get(rsp);
            
            // 3. 插入 wait states
            repeat (rsp.wait_cycles) begin
                vif.slave_cb.HREADY <= 1'b0;
                @(vif.slave_cb);
            end
            
            // 4. 驱动响应
            vif.slave_cb.HREADY <= 1'b1;
            if (rsp.xact_type == READ)
                vif.slave_cb.HRDATA <= rsp.data[0];
            vif.slave_cb.HRESP <= rsp.hresp;
        end
    endtask
endclass
```

### 关键点

- **先检测，再获取**：符合 AHB 协议时序
- **逐拍响应**：每拍从 Sequencer 获取一个响应
- **灵活控制**：通过 `wait_cycles` 插入 wait states，通过 `hresp` 注入错误

### Slave Sequence 响应

```systemverilog
class ahb_slave_response_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_slave_response_seq)
    
    // 内存模型
    bit [DATA_WIDTH-1:0] mem [bit [ADDR_WIDTH-1:0]];
    
    task body();
        ahb_transaction req, rsp;
        forever begin
            // 从 Monitor 获取请求（通过 Sequencer FIFO）
            p_sequencer.request_fifo.get(req);
            
            // 生成响应
            rsp = ahb_transaction::type_id::create("rsp");
            start_item(rsp);
            assert(rsp.randomize() with {
                rsp.xact_type   == req.xact_type;
                rsp.addr        == req.addr;
                rsp.burst_type  == req.burst_type;
                rsp.burst_size  == req.burst_size;
                rsp.hresp       == OKAY;
                rsp.wait_cycles == 0;  // 或随机等待
            }) else `uvm_fatal("RANDFAIL", "")
            
            // 读操作：从内存模型获取数据
            if (req.xact_type == READ)
                rsp.data = mem.exists(req.addr) ? mem[req.addr] : '0;
            
            finish_item(rsp);
        end
    endtask
endclass
```

### AHB HTRANS 编码

| HTRANS | 含义 | 说明 |
|--------|------|------|
| IDLE | 空闲 | 无有效传输 |
| BUSY | 忙 | Master 暂停 burst |
| NONSEQ | 非连续 | burst 第一拍或单笔传输 |
| SEQ | 连续 | burst 后续拍 |

### 关键点

- **Beat-level**: 每拍一个 transaction，无需内部维护 beat 索引
- 检测 HTRANS == NONSEQ 或 SEQ，且 HREADY == 1
- 从 Sequencer 获取响应后，插入 wait states
- 最后驱动 HREADY=1 + HRDATA/HRESP

---

## AHB Monitor 设计

### 设计决策

- **双 analysis_port**：同时提供 beat 级和 burst 级数据
  - `beat_ap`：逐拍发送（给 coverage、slave response sequence）
  - `burst_ap`：burst 完成后组装发送（给 scoreboard）
- **Beat-level Transaction**: 每拍发送一个 transaction（通过 `beat_ap.write(txn)`）
- **Burst 组装**: 内部维护 burst 状态，burst 完成后通过 `burst_ap` 发送

### 实现方案

```systemverilog
class ahb_monitor extends uvm_monitor;
    `uvm_component_utils(ahb_monitor)
    
    virtual ahb_interface.monitor_cb vif;
    
    // 双 analysis port
    uvm_analysis_port #(ahb_transaction) beat_ap;   // 逐拍（coverage、slave sequence）
    uvm_analysis_port #(ahb_transaction) burst_ap;  // burst 级（scoreboard）
    
    // Burst 上下文（用于组装 burst 级 transaction）
    ahb_transaction beat_buffer[$];  // burst 数据缓冲
    int unsigned beat_count;
    bit in_burst = 0;  // 是否在 burst 中

    function new(string name, uvm_component parent);
        super.new(name, parent);
        beat_ap  = new("beat_ap", this);
        burst_ap = new("burst_ap", this);
    endfunction
    
    task run_phase(uvm_phase phase);
        ahb_transaction txn;
        
        forever begin
            @(vif.monitor_cb);
            
            // 检测 IDLE：如果之前在 burst 中，发送上一个 INCR burst
            if (vif.monitor_cb.HTRANS == IDLE && vif.monitor_cb.HREADY && in_burst) begin
                burst_ap.write(assemble_burst(beat_buffer));
                beat_buffer.delete();
                in_burst = 0;
            end
            
            // 等待有效传输（HTRANS == NONSEQ/SEQ 且 HREADY == 1）
            if (vif.monitor_cb.HTRANS inside {NONSEQ, SEQ} && vif.monitor_cb.HREADY) begin
                // 创建单拍 transaction
                txn = ahb_transaction::type_id::create("txn");
                
                // 采样地址和控制信号
                txn.addr       = vif.monitor_cb.HADDR;
                txn.xact_type  = vif.monitor_cb.HWRITE ? WRITE : READ;
                txn.burst_type = vif.monitor_cb.HBURST;
                txn.burst_size = vif.monitor_cb.HSIZE;
                txn.prot       = vif.monitor_cb.HPROT;
                txn.hresp      = vif.monitor_cb.HRESP;
                
                // 判断是否为首拍
                txn.is_first_beat = (vif.monitor_cb.HTRANS == NONSEQ);
                
                // 采样数据
                if (txn.xact_type == WRITE)
                    txn.data = new[1](vif.monitor_cb.HWDATA);
                else
                    txn.data = new[1](vif.monitor_cb.HRDATA);
                
                // 更新 burst 上下文
                if (txn.is_first_beat) begin
                    // 发送上一个 burst（如果有，INCR 的情况）
                    if (beat_buffer.size() > 0)
                        burst_ap.write(assemble_burst(beat_buffer));
                    beat_buffer.delete();
                    beat_count = 0;
                end else begin
                    beat_count++;
                end
                txn.beat_num     = beat_count;
                txn.burst_length = get_burst_length(txn.burst_type);
                
                // 发送单拍 transaction（逐拍）
                beat_ap.write(txn);
                
                // 缓存到 burst buffer
                beat_buffer.push_back(txn);
                in_burst = 1;
                
                // 判断 burst 是否完成（固定长度）
                if (is_burst_complete(txn)) begin
                    burst_ap.write(assemble_burst(beat_buffer));
                    beat_buffer.delete();
                    in_burst = 0;
                end
            end
        end
    endtask
    
    // 组装 burst 级 transaction
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
        
        // 组装数据队列
        burst_txn.data = new[buffer.size()];
        foreach (buffer[i])
            burst_txn.data[i] = buffer[i].data[0];
        
        return burst_txn;
    endfunction
    
    // 判断 burst 是否完成（固定长度）
    function bit is_burst_complete(ahb_transaction txn);
        // SINGLE: 1 拍完成
        if (txn.burst_type == SINGLE) return 1;
        // INCR4/8/16, WRAP4/8/16: 固定拍数
        if (txn.burst_type inside {INCR4, INCR8, INCR16, WRAP4, WRAP8, WRAP16})
            return (txn.beat_num == get_burst_length(txn.burst_type) - 1);
        // INCR: 不定长，不在这里判断，在 run_phase 中检测 NONSEQ/IDLE
        return 0;
    endfunction
endclass
```

### INCR 处理逻辑

```
时钟:     1      2      3      4      5
HTRANS:  NONSEQ  SEQ    SEQ   NONSEQ  ...
HADDR:   0x1000 0x1004 0x1008 0x2000  ...

Monitor 行为：
- 周期 1: 采集 beat(0x1000)，beat_ap.write，缓存到 buffer
- 周期 2: 采集 beat(0x1004)，beat_ap.write，缓存到 buffer
- 周期 3: 采集 beat(0x1008)，beat_ap.write，缓存到 buffer
- 周期 4: 检测到新的 NONSEQ → burst_ap.write(组装的 INCR burst)
          开始新的 burst
```

### 关键点

- **固定长度 burst**（INCR4/8/16、WRAP4/8/16）：拍数到了立即发送
- **INCR burst**：检测到新的 NONSEQ 或 IDLE 时发送上一个 burst
- **SINGLE**：1 拍完成，立即发送
        end
    endtask
    
    function bit is_burst_complete(ahb_transaction txn);
        // SINGLE: 1 拍完成
        if (txn.burst_type == SINGLE) return 1;
        
        // INCR4/8/16, WRAP4/8/16: 固定拍数
        if (txn.burst_type inside {INCR4, INCR8, INCR16, WRAP4, WRAP8, WRAP16})
            return (txn.beat_num == get_burst_length(txn.burst_type) - 1);
        
        // INCR: 不定长，需要检测下一个 NONSEQ/IDLE
        // 这里简化处理，实际需要在下一拍判断
        return 0;
    endfunction
    
    function ahb_transaction assemble_burst(ahb_transaction buffer[$]);
        ahb_transaction burst_txn;
        burst_txn = ahb_transaction::type_id::create("burst_txn");
        
        burst_txn.xact_type  = buffer[0].xact_type;
        burst_txn.addr       = buffer[0].addr;
        burst_txn.burst_type = buffer[0].burst_type;
        burst_txn.burst_size = buffer[0].burst_size;
        burst_txn.prot       = buffer[0].prot;
        
        // 组装数据队列（如果需要）
        // burst_txn.data = new[buffer.size()];
        // foreach (buffer[i]) burst_txn.data[i] = buffer[i].data;
        
        return burst_txn;
    endfunction
endclass
```

### AHB Burst 类型

| Burst 类型 | 拍数 | 结束条件 |
|------------|------|----------|
| SINGLE | 1 | 固定 1 拍 |
| INCR | 1-16 | 遇到 NONSEQ/IDLE |
| INCR4/8/16 | 4/8/16 | 固定拍数 |
| WRAP4/8/16 | 4/8/16 | 固定拍数 |

### 关键点

- **Beat-level**: 每拍发送一个 transaction，无需等待 burst 完成
- 检测 HTRANS == NONSEQ/SEQ && HREADY == 1 作为有效传输
- 采样地址、控制信号、数据、响应
- **可选 burst 组装**: 根据 Scoreboard 需求决定是否组装 burst

---

## AHB Coverage 设计

### 设计决策

- **分层设计**：Agent 级 Coverage + 跨 Agent Coverage
  - **Agent 级 Coverage**：每个 Agent 一个实例，覆盖该 Agent 的特性
  - **跨 Agent Coverage**：一个实例，覆盖跨 Agent 交叉特性
- **双 analysis_port 连接**：Coverage 同时连接 `beat_ap` 和 `burst_ap`
  - `beat_ap`：覆盖逐拍特性（HTRANS 编码、wait states、HREADY 行为）
  - `burst_ap`：覆盖 burst 级特性（burst 类型、WRAP 地址边界、burst 长度）

### Agent 级 Coverage

每个 Agent 一个实例，覆盖该 Agent 的特性。

```systemverilog
class ahb_agent_coverage extends uvm_subscriber #(ahb_transaction);
    `uvm_component_utils(ahb_agent_coverage)
    
    // Beat-level covergroup
    covergroup beat_cg;
        cp_htrans: coverpoint txn.htrans {
            bins idle   = {IDLE};
            bins busy   = {BUSY};
            bins nonseq = {NONSEQ};
            bins seq    = {SEQ};
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
    
    // Burst-level covergroup
    covergroup burst_cg;
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
    endgroup
    
    // ... 实现 ...
endclass
```

### 跨 Agent Coverage

一个实例，覆盖跨 Agent 交叉特性。

```systemverilog
class ahb_cross_coverage extends uvm_component;
    `uvm_component_utils(ahb_cross_coverage)
    
    // 接收多个 Agent 的数据
    uvm_analysis_imp_decl(_master)
    uvm_analysis_imp_decl(_slave)
    
    uvm_analysis_imp_master #(ahb_transaction, ahb_cross_coverage) master_imp[];
    uvm_analysis_imp_slave #(ahb_transaction, ahb_cross_coverage) slave_imp[];
    
    // 跨 Agent 交叉覆盖
    covergroup cross_cg;
        cp_master_burst_type: coverpoint master_txn.burst_type { ... }
        cp_slave_wait_cycles: coverpoint slave_txn.wait_cycles { ... }
        cx_burst_wait: cross cp_master_burst_type, cp_slave_wait_cycles;
    endgroup
    
    // ... 实现 ...
endclass
```

### Coverage 连接示例（多 Master 多 Slave）

```
Master Agent 0 Coverage  ← Master 0 Monitor beat_ap/burst_ap
Master Agent 1 Coverage  ← Master 1 Monitor beat_ap/burst_ap
Slave Agent 0 Coverage   ← Slave 0 Monitor beat_ap/burst_ap
Slave Agent 1 Coverage   ← Slave 1 Monitor beat_ap/burst_ap
Slave Agent 2 Coverage   ← Slave 2 Monitor beat_ap/burst_ap

Cross-Agent Coverage     ← 所有 Monitor beat_ap/burst_ap
```

### 覆盖点说明

| Covergroup | 覆盖点 | 说明 |
|------------|--------|------|
| `beat_cg` | `cp_htrans` | HTRANS 编码分布 |
| | `cp_xact_type` | 读/写比例 |
| | `cp_wait_cycles` | wait state 分布 |
| | `cx_htrans_xact` | HTRANS × 读/写交叉 |
| `burst_cg` | `cp_burst_type` | burst 类型分布 |
| | `cp_burst_size` | 传输大小分布 |
| | `cp_burst_length` | burst 长度分布 |
| | `cp_wrap_boundary` | WRAP 地址对齐 |
| | `cx_burst_type_size` | burst 类型 × 传输大小交叉 |
| `cross_cg` | 跨 Agent 交叉 | Master burst × Slave wait cycles 等 |

---

## AHB Scoreboard 设计

### 设计决策

- **连接 `burst_ap`**：比对 burst 级数据，完整验证
- **统一比对逻辑**：所有 burst 类型（SINGLE/INCR/WRAP）使用相同比对逻辑

### 实现方案

```systemverilog
class ahb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ahb_scoreboard)
    
    // 双 FIFO 接收 burst 级 transaction
    uvm_analysis_imp_decl(_master)
    uvm_analysis_imp_decl(_slave)
    
    uvm_analysis_imp_master #(ahb_transaction, ahb_scoreboard) master_export;
    uvm_analysis_imp_slave #(ahb_transaction, ahb_scoreboard) slave_export;
    
    // 存储 Master 发送的 burst
    ahb_transaction master_bursts[$];
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        master_export = new("master_export", this);
        slave_export  = new("slave_export", this);
    endfunction
    
    // Master burst_ap 写入
    function void write_master(ahb_transaction t);
        master_bursts.push_back(t);
    endfunction
    
    // Slave burst_ap 写入
    function void write_slave(ahb_transaction t);
        ahb_transaction master_txn;
        
        // 从队列中取出对应的 Master burst
        if (master_bursts.size() == 0) begin
            `uvm_error("SCB", "No master burst available for comparison")
            return;
        end
        master_txn = master_bursts.pop_front();
        
        // 比对
        compare_bursts(master_txn, t);
    endfunction
    
    // 比对两个 burst
    function void compare_bursts(ahb_transaction master_txn, ahb_transaction slave_txn);
        // 检查 burst 类型
        if (master_txn.burst_type != slave_txn.burst_type)
            `uvm_error("SCB", $sformatf("Burst type mismatch: master=%s, slave=%s",
                master_txn.burst_type.name(), slave_txn.burst_type.name()))
        
        // 检查地址
        if (master_txn.addr != slave_txn.addr)
            `uvm_error("SCB", $sformatf("Address mismatch: master=0x%08h, slave=0x%08h",
                master_txn.addr, slave_txn.addr))
        
        // 检查数据长度
        if (master_txn.data.size() != slave_txn.data.size())
            `uvm_error("SCB", $sformatf("Data size mismatch: master=%0d, slave=%0d",
                master_txn.data.size(), slave_txn.data.size()))
        
        // 逐拍比对数据
        foreach (master_txn.data[i]) begin
            if (master_txn.data[i] !== slave_txn.data[i])
                `uvm_error("SCB", $sformatf("Data[%0d] mismatch: master=0x%08h, slave=0x%08h",
                    i, master_txn.data[i], slave_txn.data[i]))
        end
    endfunction
endclass
```

### Scoreboard 连接

```
Master Monitor burst_ap → Scoreboard.master_export
Slave Monitor burst_ap  → Scoreboard.slave_export
```

### 比对逻辑

| 检查项 | 说明 |
|--------|------|
| `burst_type` | burst 类型必须一致 |
| `addr` | 起始地址必须一致 |
| `data.size()` | 数据长度必须一致 |
| `data[i]` | 逐拍数据必须一致 |

### 关键点

- **统一比对**：所有 burst 类型（SINGLE/INCR/WRAP）使用相同比对逻辑
- **burst 级比对**：从 `burst_ap` 获取完整 burst，无需自己组装
- **时序假设**：假设 Master 和 Slave 的 burst_ap 按相同时序发送

---

## AHB Env 设计

### 设计决策

- **依赖注入**：所有 cfg 在上一层级显式赋值，不使用 config_db 传递配置
- **组合原则**：Env 有 env_cfg，env_cfg 包含所有 Agent 的 cfg
- **动态创建**：根据 env_cfg 中的 num 动态创建 Agent
- **暴露 API**：Agent 暴露给用户的 API 只有 cfg 和 sequencer

### Config 层级设计

```
ahb_env_config
├── master_agt_num / slave_agt_num
├── master_cfg[]  (ahb_agent_config)
├── slave_cfg[]   (ahb_agent_config)
└── slave_addr_map[]
```

### Config 实现

```systemverilog
class ahb_env_config extends uvm_object;
    `uvm_object_utils(ahb_env_config)
    
    // Agent 数量
    int master_agt_num = 1;
    int slave_agt_num  = 1;
    bit ahb_lite = 1;
    
    // Agent Config 数组（组合）
    ahb_agent_config master_cfg[];
    ahb_agent_config slave_cfg[];
    
    // Slave 地址映射
    bit [ADDR_WIDTH-1:0] slave_addr_map[];
    
    function new(string name = "ahb_env_config");
        super.new(name);
    endfunction
    
    // 初始化
    function void init();
        master_cfg = new[master_agt_num];
        slave_cfg  = new[slave_agt_num];
        foreach (master_cfg[i])
            master_cfg[i] = ahb_agent_config::type_id::create($sformatf("master_cfg[%0d]", i));
        foreach (slave_cfg[i])
            slave_cfg[i] = ahb_agent_config::type_id::create($sformatf("slave_cfg[%0d]", i));
    endfunction
    
    // AHB-Lite 快捷初始化
    function void init_lite();
        ahb_lite = 1;
        master_agt_num = 1;
        init();
    endfunction
endclass
```

### Env 实现

```systemverilog
class ahb_bus_env extends uvm_env;
    `uvm_component_utils(ahb_bus_env)
    
    // 暴露给用户的 API
    ahb_env_config env_cfg;
    
    // 内部组件
    ahb_master_agent master_agt[];
    ahb_slave_agent  slave_agt[];
    ahb_scoreboard   scb;
    ahb_agent_coverage master_cov[];
    ahb_agent_coverage slave_cov[];
    ahb_cross_coverage cross_cov;
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // 从 config_db 获取 env_cfg（仅此一处）
        if (!uvm_config_db#(ahb_env_config)::get(this, "", "env_cfg", env_cfg))
            `uvm_fatal("NOCONFIG", "ahb_env_config not set")
        
        // 动态创建 Agent
        master_agt = new[env_cfg.master_agt_num];
        foreach (master_agt[i])
            master_agt[i] = ahb_master_agent::type_id::create(
                $sformatf("master_agt[%0d]", i), this);
        
        slave_agt = new[env_cfg.slave_agt_num];
        foreach (slave_agt[i])
            slave_agt[i] = ahb_slave_agent::type_id::create(
                $sformatf("slave_agt[%0d]", i), this);
        
        // 创建 Scoreboard
        scb = ahb_scoreboard::type_id::create("scb", this);
        
        // 创建 Coverage
        master_cov = new[env_cfg.master_agt_num];
        foreach (master_cov[i])
            master_cov[i] = ahb_agent_coverage::type_id::create(
                $sformatf("master_cov[%0d]", i), this);
        
        slave_cov = new[env_cfg.slave_agt_num];
        foreach (slave_cov[i])
            slave_cov[i] = ahb_agent_coverage::type_id::create(
                $sformatf("slave_cov[%0d]", i), this);
        
        cross_cov = ahb_cross_coverage::type_id::create("cross_cov", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // 显式赋值 cfg（依赖注入）
        foreach (master_agt[i])
            master_agt[i].cfg = env_cfg.master_cfg[i];
        foreach (slave_agt[i])
            slave_agt[i].cfg = env_cfg.slave_cfg[i];
        
        // 连接 Master Agent → Scoreboard 和 Coverage
        foreach (master_agt[i]) begin
            master_agt[i].mon.burst_ap.connect(scb.master_export);
            master_agt[i].mon.beat_ap.connect(master_cov[i].analysis_export);
            master_agt[i].mon.burst_ap.connect(master_cov[i].burst_export);
        end
        
        // 连接 Slave Agent → Scoreboard 和 Coverage
        foreach (slave_agt[i]) begin
            slave_agt[i].mon.burst_ap.connect(scb.slave_export);
            slave_agt[i].mon.beat_ap.connect(slave_cov[i].analysis_export);
            slave_agt[i].mon.burst_ap.connect(slave_cov[i].burst_export);
        end
        
        // 连接跨 Agent Coverage
        foreach (master_agt[i]) begin
            master_agt[i].mon.beat_ap.connect(cross_cov.master_beat_export[i]);
            master_agt[i].mon.burst_ap.connect(cross_cov.master_burst_export[i]);
        end
        foreach (slave_agt[i]) begin
            slave_agt[i].mon.beat_ap.connect(cross_cov.slave_beat_export[i]);
            slave_agt[i].mon.burst_ap.connect(cross_cov.slave_burst_export[i]);
        end
    endfunction
endclass
```

### Test 结构设计

**设计决策**：tb_top + base_test 继承，每个 Test 有独立的 tb_top 配置 DUT 参数

### Test 继承结构

```
ahb_base_test
├── ahb_lite_test（AHB-Lite 模式）
├── ahb_burst_test（Burst 测试）
├── ahb_pipeline_test（Pipeline 测试）
├── ahb_wait_state_test（Wait State 测试）
├── ahb_error_resp_test（错误响应测试）
└── ...
```

### 文件结构

```
ahb/
├── test/
│   ├── ahb_base_test.sv          ← base_test
│   ├── ahb_lite_test.sv          ← 子 Test
│   ├── ahb_burst_test.sv         ← 子 Test
│   ├── ahb_wait_state_test.sv    ← 子 Test
│   └── ...
├── tb/
│   ├── ahb_tb_top_lite.sv        ← tb_top（AHB-Lite）
│   ├── ahb_tb_top_burst.sv       ← tb_top（Burst）
│   ├── ahb_tb_top_wait.sv        ← tb_top（Wait State）
│   └── ...
└── sim/
    ├── Makefile
    └── ...
```

### base_test 实现

```systemverilog
// ahb_base_test.sv
class ahb_base_test extends uvm_test;
    `uvm_component_utils(ahb_base_test)
    
    ahb_bus_env env;
    ahb_env_config env_cfg;
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // 创建 env_cfg
        env_cfg = ahb_env_config::type_id::create("env_cfg");
        env_cfg.init();
        
        // 创建 Env
        env = ahb_bus_env::type_id::create("env", this);
        
        // 显式赋值 cfg（依赖注入）
        env.env_cfg = env_cfg;
    endfunction
    
    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction
endclass
```

### 子 Test 实现

```systemverilog
// ahb_wait_state_test.sv
class ahb_wait_state_test extends ahb_base_test;
    `uvm_component_utils(ahb_wait_state_test)
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // 覆盖配置
        env_cfg.master_agt_num = 1;
        env_cfg.slave_agt_num  = 1;
        
        // 配置 Slave Agent 的 wait_cycles
        env_cfg.slave_cfg[0].wait_cycles = 2;
        
        // 显式赋值 cfg（依赖注入）
        env.env_cfg = env_cfg;
    endfunction
    
    task run_phase(uvm_phase phase);
        ahb_burst_write_seq seq;
        
        phase.raise_objection(this);
        
        // 启动 Sequence
        seq = ahb_burst_write_seq::type_id::create("seq");
        seq.start(env.master_agt[0].sqr);
        
        #100;
        phase.drop_objection(this);
    endtask
endclass
```

### tb_top 实现

```systemverilog
// ahb_tb_top_wait.sv
module ahb_tb_top_wait;
    // 参数配置
    parameter WAIT_CYCLES = 2;
    parameter INJECT_ERROR = 0;
    
    // Interface 实例化
    ahb_interface ahb_mst_if[1]();
    ahb_interface ahb_slv_if[1]();
    
    // DUT 例化
    ahb_slave_ram #(
        .WAIT_CYCLES(WAIT_CYCLES),
        .INJECT_ERROR(INJECT_ERROR)
    ) dut (
        .HCLK(ahb_slv_if[0].HCLK),
        .HRESETn(ahb_slv_if[0].HRESETn),
        .HSEL(ahb_slv_if[0].HSEL),
        .HTRANS(ahb_slv_if[0].HTRANS),
        .HWRITE(ahb_slv_if[0].HWRITE),
        .HSIZE(ahb_slv_if[0].HSIZE),
        .HBURST(ahb_slv_if[0].HBURST),
        .HADDR(ahb_slv_if[0].HADDR),
        .HWDATA(ahb_slv_if[0].HWDATA),
        .HRDATA(ahb_slv_if[0].HRDATA),
        .HREADY(ahb_slv_if[0].HREADY),
        .HRESP(ahb_slv_if[0].HRESP)
    );
    
    // vif 设置
    initial begin
        uvm_config_db#(virtual ahb_interface)::set(
            null,
            "*.ahb_env.mst_agt[0]",
            "vif",
            ahb_mst_if[0]
        );
        uvm_config_db#(virtual ahb_interface)::set(
            null,
            "*.ahb_env.slv_agt[0]",
            "vif",
            ahb_slv_if[0]
        );
    end
    
    // 启动测试
    initial begin
        run_test("ahb_wait_state_test");
    end
endmodule
```

### Makefile 设计

```makefile
# Makefile
TEST ?= ahb_wait_state_test

# 编译选项
COMPILE_OPTS = -sverilog -full64 -timescale=1ns/1ps
COMPILE_OPTS += +incdir+../src

# 目标
all: comp run

comp:
	vcs $(COMPILE_OPTS) -o simv ../tb/ahb_tb_top_wait.sv ../test/ahb_base_test.sv ../test/$(TEST).sv

run:
	./simv +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=UVM_MEDIUM
```

### 关键点

- **tb_top + test class**：每个 Test 有独立的 tb_top 配置 DUT 参数，test class 继承 base_test
- **base_test**：提供默认配置，子 Test 可以覆盖
- **依赖注入**：所有 cfg 在上一层级显式赋值，不使用 config_db 传递
- **config_db 限制**：仅限于从 tb_top 中传递 virtual interface

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

### Objection 管理策略

**设计决策**：只在顶层 Sequence 管理 objection，子 Sequence 不管理

```systemverilog
// 顶层 Sequence：管理 objection
class ahb_top_test_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_top_test_seq)
    
    task body();
        uvm_phase phase = get_starting_phase();
        if (phase != null)
            phase.raise_objection(this);
        
        // 启动子 Sequence
        repeat (10) begin
            ahb_burst_write_seq seq = ahb_burst_write_seq::type_id::create("seq");
            seq.start(m_sequencer);
        end
        
        if (phase != null)
            phase.drop_objection(this);
    endtask
endclass

// 子 Sequence：不管理 objection
class ahb_burst_write_seq extends uvm_sequence #(ahb_transaction);
    `uvm_object_utils(ahb_burst_write_seq)
    
    task body();
        // 只发送 burst，不管 objection
        for (int i = 0; i < burst_len; i++) begin
            // ... 发送 transaction ...
        end
    endtask
endclass
```

### 关键点

- **顶层 Sequence**：raise/drop objection，控制仿真时长
- **子 Sequence**：只负责发送 transaction，不管 objection
- **Slave Response Sequence**：使用 `forever` 循环，不需要 objection（由 Master 侧控制）
- 使用 `start_item` / `finish_item`，不用 `uvm_do_with`
- 每次 `randomize` 检查返回值

---

## Interface 设计

### 设计决策

- Interface 中使用 **clocking block** 进行信号同步
- 原因：clocking block 提供明确的时序关系，避免竞争条件

### APB Interface

```systemverilog
interface apb_interface #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input logic PCLK,
    input logic PRESETn
);
    // 信号声明
    logic                    PSEL;
    logic                    PENABLE;
    logic [ADDR_WIDTH-1:0]   PADDR;
    logic                    PWRITE;
    logic [DATA_WIDTH-1:0]   PWDATA;
    logic [DATA_WIDTH-1:0]   PRDATA;
    logic                    PREADY;
    logic                    PSLVERR;
    logic [DATA_WIDTH/8-1:0] PSTRB;  // APB4
    logic [2:0]              PPROT;  // APB4

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
```

### AHB Interface

```systemverilog
interface ahb_interface #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input logic HCLK,
    input logic HRESETn
);
    // 信号声明
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
```

### 关键点

- **Clocking block** 提供明确的时序关系（`#1` 延迟）
- **Modport** 定义信号方向，防止错误访问
- **Monitor clocking block** 只读，用于被动观测
- Driver 使用 `master_cb` 或 `slave_cb`，Monitor 使用 `monitor_cb`

---

## Testbench 结构

### 设计决策

- tb_top 为 module，包含 clock/reset 生成、Interface 例化、DUT 例化、config_db 设置
- DUT 模型为简单 Slave RAM，支持基本读写
- **vif 传递**：tb_top 使用通配符和 generate 块循环设置多个 vif

### Testbench 架构

```
tb_top (module)
├── clock/reset 生成
├── Interface 例化（多通道）
├── DUT 例化（简单 slave RAM 或 master 模型）
├── config_db 设置（vif → agent，使用通配符和 generate 块）
└── run_test()
```

### tb_top 实现

```systemverilog
module tb_top;
    // Interface 实例化
    ahb_interface ahb_mst_if[2]();
    ahb_interface ahb_slv_if[3]();
    
    // Clock/Reset 生成
    initial begin
        ahb_mst_if[0].HCLK = 0;
        ahb_mst_if[1].HCLK = 0;
        ahb_slv_if[0].HCLK = 0;
        ahb_slv_if[1].HCLK = 0;
        ahb_slv_if[2].HCLK = 0;
        forever #5 ahb_mst_if[0].HCLK = ~ahb_mst_if[0].HCLK;
    end
    
    // 使用 generate 块循环设置 vif
    genvar i;
    generate
        // 设置 Master Agent vif
        for (i = 0; i < 2; i++) begin : set_mst_vif
            initial begin
                uvm_config_db#(virtual ahb_interface)::set(
                    null,
                    $sformatf("*.ahb_env.mst_agt[%0d]", i),
                    "vif",
                    ahb_mst_if[i]
                );
            end
        end
        
        // 设置 Slave Agent vif
        for (i = 0; i < 3; i++) begin : set_slv_vif
            initial begin
                uvm_config_db#(virtual ahb_interface)::set(
                    null,
                    $sformatf("*.ahb_env.slv_agt[%0d]", i),
                    "vif",
                    ahb_slv_if[i]
                );
            end
        end
    endgenerate
    
    // DUT 例化
    // ...
    
    // 启动测试
    initial begin
        run_test();
    end
endmodule
```

### 关键点

- **tb_top**：使用通配符和 generate 块循环设置多个 vif
- **Agent build_phase**：获取 vif，传递给 driver 和 monitor
- **多通道支持**：通过 generate 块的循环支持多个 Agent

### DUT 模型

| 协议 | DUT 模型 | 说明 |
|------|----------|------|
| APB | APB Slave RAM | 可配置内存模型，支持 wait states 和错误响应 |
| AHB | AHB Slave RAM | 可配置内存模型，支持 wait states 和错误响应 |
| AHB | AHB Master DUT（可选） | 用于验证 Slave Agent |

### 设计决策

- **可配置 Slave RAM**：支持 wait states 和错误响应，可以测试更多协议特性
- **配置参数**：通过参数控制行为，如 wait_cycles、inject_error
- **内存模型**：支持 burst 读写，地址对齐

### APB Slave RAM 实现

```systemverilog
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
            // 插入 wait states
            if (wait_cnt < WAIT_CYCLES) begin
                PREADY <= 1'b0;
                wait_cnt <= wait_cnt + 1;
            end else begin
                PREADY <= 1'b1;
                wait_cnt <= 0;
                
                // 错误注入
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
```

### AHB Slave RAM 实现

```systemverilog
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
            HREADY <= 1'b1;
            HRESP  <= 2'b00;  // OKAY
            HRDATA <= '0;
            wait_cnt <= 0;
        end else if (HSEL && HTRANS inside {NONSEQ, SEQ}) begin
            // 插入 wait states
            if (wait_cnt < WAIT_CYCLES) begin
                HREADY <= 1'b0;
                wait_cnt <= wait_cnt + 1;
            end else begin
                HREADY <= 1'b1;
                wait_cnt <= 0;
                
                // 错误注入
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
```

### DUT 模型配置

**设计决策**：通过参数传递配置，每个 Test 有独立的 tb_top

```systemverilog
// tb_top_wait_states.sv（测试 wait states）
module tb_top_wait_states;
    // 参数配置
    parameter WAIT_CYCLES = 2;
    parameter INJECT_ERROR = 0;
    
    // DUT 例化
    ahb_slave_ram #(
        .WAIT_CYCLES(WAIT_CYCLES),
        .INJECT_ERROR(INJECT_ERROR)
    ) dut (
        // ...
    );
    
    // ... 其他代码 ...
endmodule

// tb_top_error_resp.sv（测试错误响应）
module tb_top_error_resp;
    // 参数配置
    parameter WAIT_CYCLES = 0;
    parameter INJECT_ERROR = 1;
    
    // DUT 例化
    ahb_slave_ram #(
        .WAIT_CYCLES(WAIT_CYCLES),
        .INJECT_ERROR(INJECT_ERROR)
    ) dut (
        // ...
    );
    
    // ... 其他代码 ...
endmodule
```

### 关键点

- **参数传递**：通过 parameter 传递配置，不需要 config_db
- **独立 tb_top**：每个 Test 有独立的 tb_top，配置清晰
- **灵活**：可以通过 generate 块动态配置
- **可配置**：通过参数控制 wait states 和错误注入
- **burst 支持**：支持 burst 读写，地址对齐
- **协议特性**：支持 PREADY/HREADY、PSLVERR/HRESP 等协议特性
- tb_top 通过 `+incdir+../src` 包含 src 目录

---

## Makefile 设计

### 设计决策

- APB 和 AHB 各有独立 Makefile
- 原因：APB 和 AHB 是独立的 VIP，可以单独使用
- **一个 Makefile，通过变量控制 Test**：复用性好，避免重复

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

# 测试变量
TEST ?= ahb_wait_state_test
WAIT_CYCLES ?= 2
INJECT_ERROR ?= 0

# 编译选项
COMPILE_OPTS = -sverilog -full64 -timescale=1ns/1ps
COMPILE_OPTS += +define+UVM_PACKER_MAX_BYTES=1500000
COMPILE_OPTS += +define+UVM_DISABLE_AUTO_ITEM_RECORDING
COMPILE_OPTS += +incdir+../src
COMPILE_OPTS += +define+WAIT_CYCLES=$(WAIT_CYCLES)
COMPILE_OPTS += +define+INJECT_ERROR=$(INJECT_ERROR)

# 支持覆盖率
COVERAGE_OPTS = -cm line+cond+fsm+tgl
COVERAGE_OPTS += -cm_dir $(SIM_OUTPUT)/coverage

# 支持波形
WAVE_OPTS = +define+WAVE_DUMP

# 目标
all: comp run

comp:
	vcs $(COMPILE_OPTS) $(COVERAGE_OPTS) $(WAVE_OPTS) -o $(SIM_OUTPUT)/simv \
		../tb/ahb_tb_top_$(TEST).sv \
		../test/ahb_base_test.sv \
		../test/$(TEST).sv

run:
	$(SIM_OUTPUT)/simv +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=UVM_MEDIUM $(COVERAGE_OPTS)

cov:
	urg -dir $(SIM_OUTPUT)/coverage.vdb -report $(SIM_OUTPUT)/coverage_report

clean:
	rm -rf $(SIM_OUTPUT) csrc *.log *.key *.vpd *.vdb
```

### 使用示例

```bash
# 运行默认测试
make

# 运行指定测试
make TEST=ahb_burst_test

# 运行带参数的测试
make TEST=ahb_wait_state_test WAIT_CYCLES=4

# 运行带错误注入的测试
make TEST=ahb_error_resp_test INJECT_ERROR=1

# 运行覆盖率
make cov

# 清理
make clean
```

### 关键点

- **一个 Makefile**：通过变量控制 Test 和参数
- **复用性好**：common 配置只在 Makefile 中设置一次
- **灵活**：可以通过变量控制 Test 和参数
- **支持覆盖率和波形**：通过变量控制是否启用

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

**源码（src/）- 18 个文件：**
1. `ahb_defines.svh` — 宏定义（宽度、版本控制）
2. `ahb_interface.sv` — 接口（含 clocking block）
3. `ahb_transaction.sv` — Transaction（beat-level，data[] 队列）
4. `ahb_agent_config.sv` — Agent 配置（单个 Agent）
5. `ahb_env_config.sv` — Env 配置（包含 Agent 配置数组）
6. `ahb_sequencer.sv` — Sequencer（含 request_fifo）
7. `ahb_monitor.sv` — Monitor（双 analysis_port：beat_ap + burst_ap）
8. `ahb_master_driver.sv` — Master Driver（pipeline：address_thread + data_thread）
9. `ahb_slave_driver.sv` — Slave Driver（检测有效传输，插入 wait states）
10. `ahb_master_agent.sv` — Master Agent（含 vif 获取、依赖注入）
11. `ahb_slave_agent.sv` — Slave Agent（含 Monitor→Sequence FIFO）
12. `ahb_bus_env.sv` — Env（动态创建 Agent、依赖注入）
13. `ahb_sequences.sv` — Sequence 库（含 burst 地址计算）
14. `ahb_agent_coverage.sv` — Agent 级 Coverage
15. `ahb_cross_coverage.sv` — 跨 Agent Coverage
16. `ahb_scoreboard.sv` — Scoreboard（burst 级比对）
17. `ahb_slave_ram.sv` — DUT 模型（可配置 wait states 和错误注入）
18. `ahb_pkg.sv` — Package 封装

**TB（tb/）- 多个文件：**
19. `ahb_tb_top_lite.sv` — tb_top（AHB-Lite 模式）
20. `ahb_tb_top_burst.sv` — tb_top（Burst 测试）
21. `ahb_tb_top_wait.sv` — tb_top（Wait State 测试）
22. `ahb_tb_top_error.sv` — tb_top（错误响应测试）
23. `ahb_tb_top_pipeline.sv` — tb_top（Pipeline 测试）
24. `ahb_tb_top_slave.sv` — tb_top（Slave Agent 测试）
25. `ahb_tb_top_full_bus.sv` — tb_top（Full AHB 测试）
26. `ahb_tb_pkg.sv` — TB package

**测试（test/）- 11 个文件：**
27. `ahb_base_test.sv` — base_test（默认配置）
28. `ahb_lite_test.sv` — AHB-F14, F20
29. `ahb_burst_test.sv` — AHB-F02, F03, F04, F18
30. `ahb_pipeline_test.sv` — AHB-F11
31. `ahb_slave_test.sv` — AHB-F12, F13
32. `ahb_wait_state_test.sv` — AHB-F05
33. `ahb_error_resp_test.sv` — AHB-F06
34. `ahb_mastlock_test.sv` — AHB-F07
35. `ahb_burst_size_test.sv` — AHB-F01, F08
36. `ahb_busy_test.sv` — AHB-F09
37. `ahb_full_bus_test.sv` — AHB-F15, F16, F17, F19

**构建（sim/）- 2 个文件：**
38. `Makefile` — 一个 Makefile，通过变量控制 Test 和参数
39. `.gitignore`

### 关键点

- 源码按照依赖关系排序，确保编译顺序正确
- TB 按照依赖关系排序，确保编译顺序正确
- 测试按照 feature 依赖排序，确保测试覆盖完整
- 构建最后创建，确保 Makefile 包含所有文件

---

## AHB Transaction 设计

### 设计决策

- **单一类型，灵活使用**: 同一个 `ahb_transaction` 类型，通过 `data[]` 队列长度区分 beat/burst
  - **Beat-level**（Driver 使用）：`data[]` 队列长度为 1
  - **Burst-level**（Monitor burst_ap 使用）：`data[]` 队列长度为 burst 长度
- **遵循 UVM Cookbook**: Driver 简单无状态，Sequence 负责 burst 管理
- **Pipeline 天然支持**: address_thread 和 data_thread 直接处理单拍，无需内部拆分

### 字段定义

| 字段 | 类型 | 说明 | 归属 | 填充来源 |
|---|---|---|---|---|
| `xact_type` | `xact_type_e` | READ / WRITE | 通用 | Sequence（Master）/ Monitor（采样 HWRITE） |
| `addr` | `bit [ADDR_WIDTH-1:0]` | 当前拍地址 | 通用 | Sequence（计算）/ Monitor（采样 HADDR） |
| `burst_type` | `hburst_e` | burst 类型（首拍有效） | 通用 | Sequence / Monitor（采样 HBURST） |
| `burst_size` | `hsize_e` | 8/16/32/64/... bit | 通用 | Sequence / Monitor（采样 HSIZE） |
| `data[]` | `bit [DATA_WIDTH-1:0]` | 数据队列（beat 时长度 1，burst 时长度 N） | 通用 | Sequence / Monitor（采样 HWDATA/HRDATA） |
| `prot` | `bit [3:0]` | 保护类型 | 通用 | Sequence / Monitor（采样 HPROT） |
| `hresp` | `hresp_e` | 响应（OKAY/ERROR） | 响应字段 | Slave Driver / Monitor（采样 HRESP） |
| `wait_cycles` | `int unsigned` | 等待周期（Slave 专用） | **Slave 专用** | Slave Sequence（随机化） |
| `beat_num` | `int unsigned` | 当前是第几拍 | 上下文信息 | Sequence（计数器）/ Monitor（计数器） |
| `burst_length` | `int unsigned` | burst 总拍数 | 上下文信息 | Sequence（从 burst_type 推算）/ Monitor（从 HBURST 推算） |
| `is_first_beat` | `bit` | 是否首拍 | 上下文信息 | Sequence（beat_num==0）/ Monitor（HTRANS==NONSEQ） |
| `is_last_beat` | `bit` | 是否末拍 | 上下文信息 | Sequence（beat_num==burst_length-1）/ Monitor（拍数到达） |

### 数据队列使用规则

| 场景 | `data[]` 长度 | 说明 |
|------|---------------|------|
| Driver 从 Sequencer 获取 | 1 | 单拍驱动 |
| Slave Sequence 生成响应 | 1 | 单拍响应 |
| Monitor `beat_ap` 发送 | 1 | 逐拍采集 |
| Monitor `burst_ap` 发送 | N | burst 完整数据 |

### 上下文字段填充说明

- **Sequence 发送时**：Sequence 自己维护 beat 计数器，填充 `beat_num`、`burst_length`、`is_first_beat`、`is_last_beat`
- **Monitor 采集时**：Monitor 从总线信号推断
  - `is_first_beat`：`vif.HTRANS == NONSEQ`
  - `beat_num`：内部计数器（首拍清零，每拍递增）
  - `burst_length`：从 `vif.HBURST` 推算
  - `is_last_beat`：`beat_num == burst_length - 1`（固定长度）或检测到下一个 NONSEQ/IDLE（INCR）

### 设计要点

- `wait_cycles` 是 **Slave 专用**字段
  - Slave Driver：每拍前先等 `wait_cycles` 拍，再驱动数据
  - Master Driver：不处理 `wait_cycles`
  - Monitor：记录实际观测到的 wait state，不依赖 `wait_cycles`
- `burst_type` 在首拍指定，后续拍由 Driver 根据协议自动处理
- `beat_num`、`burst_length`、`is_first_beat`、`is_last_beat` 用于上下文信息，方便调试和易读性

### 关键方法

| 方法 | 说明 | 使用场景 |
|------|------|----------|
| `get_transfer_size()` | 返回单次传输字节数（根据 burst_size） | Sequence、Driver、Monitor |
| `get_beat_addr(int beat)` | 返回第 N 拍地址（支持 WRAP 计算） | Sequence |
| `calc_next_addr()` | 根据当前地址和 burst 类型计算下一拍地址 | Sequence |
| `calc_wrap_addr(base_addr, burst_len, beat_num)` | WRAP 地址计算 | Sequence |

### WRAP 地址计算实现

```systemverilog
class ahb_transaction extends uvm_sequence_item;
    // ... 其他字段和方法 ...
    
    // 计算 beat 地址（支持 WRAP）
    function bit [ADDR_WIDTH-1:0] get_beat_addr(int beat);
        int transfer_size = get_transfer_size();  // 字节数
        int burst_len = get_burst_length();
        bit [ADDR_WIDTH-1:0] aligned_addr;
        int wrap_boundary;
        
        case (burst_type)
            // INCR：简单递增
            INCR, INCR4, INCR8, INCR16:
                return addr + beat * transfer_size;
            
            // WRAP：地址到边界回绕
            WRAP4, WRAP8, WRAP16: begin
                wrap_boundary = burst_len * transfer_size;
                aligned_addr = (addr / wrap_boundary) * wrap_boundary;
                return aligned_addr + ((addr - aligned_addr + beat * transfer_size) % wrap_boundary);
            end
            
            // SINGLE：只有一拍
            SINGLE:
                return addr;
            
            default:
                return addr + beat * transfer_size;
        endcase
    endfunction
    
    // 计算下一拍地址（相对当前地址）
    function bit [ADDR_WIDTH-1:0] calc_next_addr();
        return get_beat_addr(beat_num + 1);
    endfunction
endclass
```

### WRAP 地址计算示例

```
WRAP4, 起始地址 0x1004, 传输大小 4 字节:
- wrap_boundary = 4 * 4 = 16 字节 (0x10)
- aligned_addr = (0x1004 / 0x10) * 0x10 = 0x1000

Beat 0: (0x1004 - 0x1000 + 0*4) % 16 + 0x1000 = 0x1004
Beat 1: (0x1004 - 0x1000 + 1*4) % 16 + 0x1000 = 0x1008
Beat 2: (0x1004 - 0x1000 + 2*4) % 16 + 0x1000 = 0x100C
Beat 3: (0x1004 - 0x1000 + 3*4) % 16 + 0x1000 = 0x1000  ← 回绕
```

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
