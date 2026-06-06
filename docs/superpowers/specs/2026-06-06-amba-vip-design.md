# AMBA APB & AHB VIP 设计文档

> 日期：2026-06-06
> 状态：设计完成，准备开发

---

## 文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| **术语表** | `CONTEXT.md` | 术语权威定义，设计决策权威来源 |
| **Feature Checklist** | `vip/amba/features_checklist.md` | TDD 执行阶段使用，每个 feature 对应至少一个测试 |
| **编码规范** | `vip/amba/uvm_coding_guidelines.md` | UVM VIP 编码规范，Sequence 发送方式、Factory 使用等 |
| **VCS VIP 参考** | `/mnt/d/Download/FDM/vip_docs_2026.03/vip_docs_2026.03/doc/` | VCS VIP 用户指南，设计对齐参考 |

### 渐进式披露原则

- 本文档（design.md）：目标、架构概览、文件清单
- 详细设计决策：查阅 `CONTEXT.md`
- 编码规范：查阅 `uvm_coding_guidelines.md`
- VCS VIP 实现细节：查阅 VCS VIP 用户指南

---

## 1. 目标

在 `vip/amba/` 下开发完整的 APB 和 AHB VIP，支持 APB3/4 + AHB-Lite/Full AHB，预留 APB5/AHB5 扩展点。采用 TDD 开发，VCS 仿真，产出可直接用于项目的验证 IP。

## 2. 目录结构

```
vip/amba/
├── apb/
│   ├── src/
│   │   ├── apb_pkg.sv              # package 封装，`include 所有组件
│   │   ├── apb_defines.svh         # 宽度宏、版本控制宏
│   │   ├── apb_interface.sv        # 参数化 interface（宏控制宽度）
│   │   ├── apb_transaction.sv      # sequence item（单笔传输）
│   │   ├── apb_config.sv           # agent_config + system_config
│   │   ├── apb_driver.sv           # master driver
│   │   ├── apb_monitor.sv          # passive monitor
│   │   ├── apb_sequencer.sv        # uvm_sequencer 参数化
│   │   ├── apb_agent.sv            # master/slave agent
│   │   ├── apb_slave_driver.sv     # slave driver（响应 DUT master）
│   │   ├── apb_sequences.sv        # 基础 sequence 库
│   │   ├── apb_coverage.sv         # functional coverage
│   │   └── apb_scoreboard.sv       # 数据比对
│   ├── tb/
│   │   ├── apb_tb_top.sv           # module test_top
│   │   └── apb_tb_pkg.sv           # tb 专用 package
│   ├── test/
│   │   ├── apb_base_test.sv
│   │   ├── apb_smoke_test.sv
│   │   ├── apb_random_test.sv
│   │   ├── apb_directed_test.sv
│   │   ├── apb_wait_state_test.sv
│   │   ├── apb_slverr_test.sv
│   │   ├── apb_pstrb_test.sv
│   │   ├── apb_slave_agent_test.sv
│   │   └── apb_multi_slave_test.sv
│   └── sim/
│       ├── Makefile
│       └── .gitignore
│
└── ahb/
    ├── src/
    │   ├── ahb_pkg.sv
    │   ├── ahb_defines.svh
    │   ├── ahb_interface.sv
    │   ├── ahb_transaction.sv       # 单笔传输，burst 用 data[] 队列
    │   ├── ahb_config.sv
    │   ├── ahb_master_driver.sv     # pipelined master driver
    │   ├── ahb_slave_driver.sv
    │   ├── ahb_monitor.sv           # 观测完整 burst
    │   ├── ahb_sequencer.sv
    │   ├── ahb_master_agent.sv
    │   ├── ahb_slave_agent.sv       # 含 Monitor→Sequence FIFO 连接
    │   ├── ahb_bus_env.sv           # 多 master/slave 总线环境
    │   ├── ahb_sequences.sv
    │   ├── ahb_coverage.sv
    │   └── ahb_scoreboard.sv
    ├── tb/
    │   ├── ahb_tb_top.sv
    │   └── ahb_tb_pkg.sv
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

## 3. 命名规范

- Package 前缀：`hx_`（如 `hx_apb_pkg`、`hx_ahb_pkg`）
- Package 内部类名不加前缀（如 `apb_transaction`、`ahb_driver`）
- 使用时：`import hx_apb_pkg::*;` 或 `hx_apb_pkg::apb_transaction`

## 3.1 Interface 设计

- Interface 中使用 **clocking block** 进行信号同步
- 每个 interface 包含三个 clocking block：
  - `master_cb`：Master Driver 使用
  - `slave_cb`：Slave Driver 使用
  - `monitor_cb`：Monitor 使用（只读）
- 通过 modport 定义信号方向，防止错误访问
- 详细实现见 `CONTEXT.md`

## 4. 宽度控制

通过 `defines.svh` 中的宏控制信号宽度，interface 和 transaction 共用同一组宏：

| 宏 | 默认值 | 说明 |
|---|---|---|
| `APB_ADDR_WIDTH` | 32 | APB 地址宽度 |
| `APB_DATA_WIDTH` | 32 | APB 数据宽度 |
| `AHB_ADDR_WIDTH` | 32 | AHB 地址宽度 |
| `AHB_DATA_WIDTH` | 32 | AHB 数据宽度 |

用户编译时通过 `+define+APB_ADDR_WIDTH=16` 覆盖。

## 5. 协议版本控制

通过条件编译宏控制特性启用：

| 宏 | 说明 |
|---|---|
| `APB_APB4_ENABLE` | 启用 APB4 特性（PSTRB、PPROT） |
| `APB_APB5_ENABLE` | 启用 APB5 特性（预留） |
| `AHB_AHB5_ENABLE` | 启用 AHB5 特性（预留） |

## 6. Transaction 设计

### 6.1 APB Transaction

单笔传输，字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `addr` | `bit [ADDR_WIDTH-1:0]` | 地址 |
| `data` | `bit [DATA_WIDTH-1:0]` | 数据 |
| `write` | `bit` | 1=写, 0=读 |
| `idle_cycles` | `int unsigned` | 传输间 idle 拍数 |
| `strb` | `bit [DATA_WIDTH/8-1:0]` | APB4 字节选通 |
| `prot` | `bit [2:0]` | APB4 保护类型 |
| `slverr` | `bit` | 响应（monitor/driver 填充） |

### 6.2 AHB Transaction

一个 transaction = 一个完整 burst（VCS 方式），字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `xact_type` | `xact_type_e` | READ / WRITE |
| `addr` | `bit [ADDR_WIDTH-1:0]` | 起始地址 |
| `burst_type` | `hburst_e` | SINGLE/INCR/WRAP4/INCR4/... |
| `burst_size` | `hsize_e` | 8/16/32/64/... bit |
| `data[]` | `bit [DATA_WIDTH-1:0]` | burst 数据队列 |
| `prot` | `bit [3:0]` | 保护类型 |
| `hresp` | `hresp_e` | 响应（OKAY/ERROR） |
| `num_wait_cycles[]` | `int unsigned` | 每拍等待周期（slave 用） |

关键方法：
- `get_burst_length()` — 返回 burst 拍数
- `get_transfer_size()` — 返回单次传输字节数
- `get_beat_addr(int beat)` — 返回第 N 拍地址（支持 WRAP 计算）

约束：
- `data.size()` 由 `burst_type` 自动约束
- `num_wait_cycles.size()` == `data.size()`

## 7. Config 设计

两层配置：`agent_config`（单个 agent）+ `system_config`（总线环境）。

### 7.1 APB Config

- `apb_agent_config`：`active`、`apb4_enable`、`addr_width`、`data_width`、`vif`、功能开关
- `apb_system_config`：`num_slaves`、`master_cfg`、`slave_cfg[]`、`slave_addr_map[]`

### 7.2 AHB Config

- `ahb_agent_config`：`active`、`ahb5_enable`、`addr_width`、`data_width`、`vif`、功能开关
- `ahb_system_config`：`ahb_lite`、`num_masters`、`num_slaves`、`master_cfg[]`、`slave_cfg[]`、`slave_addr_map[]`、`arb_policy`

AHB-Lite 快捷初始化：`init_lite()` 设 `num_masters=1`。

## 8. Agent 架构

### 8.1 APB Agent

单一 Agent 类，通过 config 控制角色：

- **Monitor**：始终创建，被动观测 SETUP→ACCESS 流程
- **Driver（Master 模式）**：主动驱动 PSEL/PENABLE/PADDR/PWDATA，等待 PREADY
- **Driver（Slave 模式）**：被动响应，等待 PSEL，驱动 PRDATA/PREADY/PSLVERR

### 8.2 AHB Agent（拆分 Master/Slave）

- `ahb_master_agent`：master_driver + sequencer + monitor
- `ahb_slave_agent`：slave_driver + slave_sequencer + slave_monitor

AHB 拆分原因：总线仲裁需要独立控制 master/slave。

### 8.3 Slave Agent 内部连接（Monitor → Sequence 通知机制）

Slave Agent 的 `connect_phase` 中显式连接 Monitor 的 `analysis_port` 到 Sequencer 的 `analysis_fifo`：

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

Slave Sequencer 声明 FIFO：

```systemverilog
class ahb_slave_sequencer extends uvm_sequencer #(ahb_transaction);
    uvm_tlm_analysis_fifo #(ahb_transaction) request_fifo;
    // ...
endclass
```

Slave Sequence 从 FIFO 获取 DUT 请求：

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

数据流：
```
DUT 发起传输 → Slave Monitor 观测 → ap.write(txn)
    → sqr.request_fifo → Slave Sequence: get(req)
    → 生成响应 → start_item/finish_item → Slave Driver 驱动回 DUT
```

### 8.4 Driver 行为

**APB Master Driver FSM：**
1. Idle cycles → SETUP（PSEL=1, PENABLE=0, 驱动 PADDR/PWRITE/PWDATA）
2. ACCESS（PENABLE=1）→ 等待 PREADY=1 → 采样 PRDATA/PSLVERR → IDLE

**APB Slave Driver：**
1. 等待 PSEL=1 → 从 sequencer 获取响应 → 驱动 PRDATA/PREADY/PSLVERR

**AHB Master Driver：**
1. Address phase：驱动 HADDR/HTRANS/HWRITE/HSIZE/HBURST
2. Data phase：写操作驱动 HWDATA，读操作采样 HRDATA
3. 等待 HREADY=1
4. 支持 pipeline：address phase 和 data phase 重叠

**AHB Slave Driver：**
1. 检测有效传输（NONSEQ/SEQ）→ 从 sequencer 获取响应
2. 插入 wait states（HREADY=0）→ 驱动 HREADY=1 + HRDATA/HRESP

### 8.5 Monitor 行为

**APB Monitor：**
1. 检测 SETUP（PSEL=1, PENABLE=0）→ 采样地址
2. 等 ACCESS 完成（PREADY=1）→ 采样数据 → `ap.write(txn)`

**AHB Monitor：**
1. 检测 burst 起始（NONSEQ + HREADY=1）→ 记录地址/控制信号
2. 循环采样每拍数据直到 burst 完成 → `ap.write(txn)`

### 8.6 Active/Passive 切换

| 场景 | Agent 模式 | 说明 |
|---|---|---|
| Block-level，验证 Slave DUT | Master = ACTIVE | VIP 驱动 DUT |
| Block-level，验证 Master DUT | Slave = ACTIVE | VIP 响应 DUT |
| SoC-level，真实硬件已集成 | Slave = PASSIVE | 只观测，不驱动 |

## 9. Sequence 库

遵循 `uvm_coding_guidelines.md`，使用 `start_item` / `finish_item`，不用 `uvm_do_with`。

### 9.1 APB Sequences

| Sequence | 说明 |
|---|---|
| `apb_write_seq` | 单笔写 |
| `apb_read_seq` | 单笔读，从 response 获取数据 |
| `apb_rw_seq` | 连续随机读写 |

### 9.2 AHB Sequences

| Sequence | 说明 |
|---|---|
| `ahb_single_write_seq` | 单笔 SINGLE 写 |
| `ahb_single_read_seq` | 单笔 SINGLE 读 |
| `ahb_burst_write_seq` | Burst 写（INCR4/WRAP8 等） |
| `ahb_random_rw_seq` | 随机读写 |
| `ahb_slave_response_seq` | Slave 响应（forever 循环） |

## 10. 协议特性表与测试映射

### 10.1 APB 协议特性表

| ID | 版本 | 特性 | 说明 | 测试用例 |
|----|------|------|------|----------|
| APB-F01 | APB3 | 基本写传输 | PSEL→PENABLE→PREADY，写入 PWDATA | `apb_smoke_test` |
| APB-F02 | APB3 | 基本读传输 | PSEL→PENABLE→PREADY，采样 PRDATA | `apb_smoke_test` |
| APB-F03 | APB3 | PREADY=0 等待 | Slave 插入 wait state，driver/monitor 正确等待 | `apb_wait_state_test` |
| APB-F04 | APB3 | PSLVERR 错误响应 | Slave 返回错误，driver 正确采样 | `apb_slverr_test` |
| APB-F05 | APB3 | 连续传输 | back-to-back 传输，IDLE→SETUP 无缝衔接 | `apb_random_test` |
| APB-F06 | APB3 | Idle cycles | 传输间可配置 idle 拍数 | `apb_random_test` |
| APB-F07 | APB3 | Slave Agent 驱动 | Slave Driver 响应 DUT Master 请求 | `apb_slave_agent_test` |
| APB-F08 | APB3 | 多 Slave 地址译码 | system_config 地址映射，多 slave 实例 | `apb_multi_slave_test` |
| APB-F09 | APB3 | Passive 模式 | Monitor 只观测不驱动 | `apb_smoke_test`（slave_cfg.passive） |
| APB-F10 | APB4 | PSTRB 字节选通 | 部分字节写入，验证 mem 对应字节更新 | `apb_pstrb_test` |
| APB-F11 | APB4 | PPROT 保护类型 | Secure/Non-secure 传输 | `apb_pstrb_test` |
| APB-F12 | APB4 | 无 PSTRB 时默认行为 | APB3 模式下 strb=4'hF | `apb_smoke_test` |
| APB-F13 | 通用 | Factory override | test 可替换 driver/monitor | `apb_directed_test` |
| APB-F14 | 通用 | Config Object 模式 | agent_config / system_config 传递 | 所有测试 |

### 10.2 AHB 协议特性表

| ID | 版本 | 特性 | 说明 | 测试用例 |
|----|------|------|------|----------|
| AHB-F01 | AHB | SINGLE 传输 | 单笔读/写 | `ahb_lite_test` |
| AHB-F02 | AHB | INCR burst | 不定长 burst（1-16 拍） | `ahb_burst_test` |
| AHB-F03 | AHB | INCR4/8/16 burst | 固定长度递增 burst | `ahb_burst_test` |
| AHB-F04 | AHB | WRAP4/8/16 burst | 回环 burst，地址到边界回绕 | `ahb_burst_test` |
| AHB-F05 | AHB | HREADY=0 等待 | Slave 插入 wait state | `ahb_wait_state_test` |
| AHB-F06 | AHB | HRESP=ERROR | Slave 返回错误响应 | `ahb_error_resp_test` |
| AHB-F07 | AHB | HMASTLOCK 锁定 | 原子锁定传输 | `ahb_mastlock_test` |
| AHB-F08 | AHB | 不同 burst_size | 8/16/32/64 bit 传输大小 | `ahb_burst_size_test` |
| AHB-F09 | AHB | BUSY 传输 | Master 插入 BUSY 等待 | `ahb_busy_test` |
| AHB-F10 | AHB | IDLE 传输 | 无有效传输 | `ahb_random_test` |
| AHB-F11 | AHB | Pipeline 重叠 | Address phase 和 Data phase 重叠 | `ahb_pipeline_test` |
| AHB-F12 | AHB | Slave Agent 响应 | Slave Monitor→Sequence→Driver 链路 | `ahb_slave_test` |
| AHB-F13 | AHB | Slave 内存模型 | Slave Sequence 查内存返回数据 | `ahb_slave_test` |
| AHB-F14 | AHB-Lite | 单 Master 模式 | 无仲裁，1 master 直连 slave | `ahb_lite_test` |
| AHB-F15 | Full AHB | 多 Master 仲裁 | Round-robin 仲裁，多 master 竞争 | `ahb_full_bus_test` |
| AHB-F16 | Full AHB | HBUSREQ/HGRANT | 总线请求/授权信号 | `ahb_full_bus_test` |
| AHB-F17 | Full AHB | Default Slave | 越界地址返回 ERROR | `ahb_full_bus_test` |
| AHB-F18 | AHB | PROTECT 信号 | HPROT[3:0] 保护类型 | `ahb_burst_test` |
| AHB-F19 | AHB | Slave 地址译码 | 多 slave 地址映射 | `ahb_full_bus_test` |
| AHB-F20 | AHB | Passive 模式 | Monitor 只观测不驱动 | `ahb_lite_test`（slave_cfg.passive） |
| AHB-F21 | 通用 | Factory override | test 可替换 driver/monitor | 所有测试 |
| AHB-F22 | 通用 | Config Object 模式 | agent_config / system_config 传递 | 所有测试 |

### 10.3 测试覆盖矩阵

```
APB 测试覆盖：
┌──────────────────────────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐
│ Feature \ Test           │smoke│rand │dir  │wait │slve │pstrb│slag │mslv │
├──────────────────────────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┤
│ APB-F01 基本写           │  ✅ │  ✅ │  ✅ │     │     │     │     │     │
│ APB-F02 基本读           │  ✅ │  ✅ │  ✅ │     │     │     │     │     │
│ APB-F03 PREADY=0         │     │     │     │  ✅ │     │     │     │     │
│ APB-F04 PSLVERR          │     │     │     │     │  ✅ │     │     │     │
│ APB-F05 连续传输         │     │  ✅ │     │     │     │     │     │     │
│ APB-F06 Idle cycles      │     │  ✅ │     │     │     │     │     │     │
│ APB-F07 Slave Agent      │     │     │     │     │     │     │  ✅ │     │
│ APB-F08 多 Slave         │     │     │     │     │     │     │     │  ✅ │
│ APB-F09 Passive 模式     │  ✅ │     │     │     │     │     │     │     │
│ APB-F10 PSTRB            │     │     │     │     │     │  ✅ │     │     │
│ APB-F11 PPROT            │     │     │     │     │     │  ✅ │     │     │
│ APB-F12 无 PSTRB 默认    │  ✅ │     │     │     │     │     │     │     │
│ APB-F13 Factory override │     │     │  ✅ │     │     │     │     │     │
│ APB-F14 Config Object    │  ✅ │  ✅ │  ✅ │  ✅ │  ✅ │  ✅ │  ✅ │  ✅ │
└──────────────────────────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘

AHB 测试覆盖：
┌──────────────────────────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐
│ Feature \ Test           │lite │burst│pipe │slve │wait │err  │lock │size │busy │full │rand │
├──────────────────────────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┤
│ AHB-F01 SINGLE           │  ✅ │  ✅ │     │     │     │     │     │  ✅ │     │     │     │
│ AHB-F02 INCR             │     │  ✅ │     │     │     │     │     │     │     │     │  ✅ │
│ AHB-F03 INCR4/8/16       │     │  ✅ │     │     │     │     │     │     │     │     │     │
│ AHB-F04 WRAP4/8/16       │     │  ✅ │     │     │     │     │     │     │     │     │     │
│ AHB-F05 HREADY=0         │     │     │     │     │  ✅ │     │     │     │     │     │     │
│ AHB-F06 HRESP=ERROR      │     │     │     │     │     │  ✅ │     │     │     │     │     │
│ AHB-F07 HMASTLOCK        │     │     │     │     │     │     │  ✅ │     │     │     │     │
│ AHB-F08 burst_size       │     │     │     │     │     │     │     │  ✅ │     │     │     │
│ AHB-F09 BUSY             │     │     │     │     │     │     │     │     │  ✅ │     │     │
│ AHB-F10 IDLE             │     │     │     │     │     │     │     │     │     │     │  ✅ │
│ AHB-F11 Pipeline         │     │     │  ✅ │     │     │     │     │     │     │     │     │
│ AHB-F12 Slave 响应       │     │     │     │  ✅ │     │     │     │     │     │     │     │
│ AHB-F13 Slave 内存       │     │     │     │  ✅ │     │     │     │     │     │     │     │
│ AHB-F14 AHB-Lite         │  ✅ │     │     │     │     │     │     │     │     │     │     │
│ AHB-F15 多 Master 仲裁   │     │     │     │     │     │     │     │     │     │  ✅ │     │
│ AHB-F16 HBUSREQ/HGRANT   │     │     │     │     │     │     │     │     │     │  ✅ │     │
│ AHB-F17 Default Slave    │     │     │     │     │     │     │     │     │     │  ✅ │     │
│ AHB-F18 HPROT            │     │  ✅ │     │     │     │     │     │     │     │     │     │
│ AHB-F19 Slave 地址译码   │     │     │     │     │     │     │     │     │     │  ✅ │     │
│ AHB-F20 Passive 模式     │  ✅ │     │     │     │     │     │     │     │     │     │     │
│ AHB-F21 Factory override │     │     │     │     │     │     │     │     │     │     │     │
│ AHB-F22 Config Object    │  ✅ │  ✅ │  ✅ │  ✅ │  ✅ │  ✅ │  ✅ │  ✅ │  ✅ │  ✅ │  ✅ │
└──────────────────────────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘
```

## 11. Testbench 结构

```
tb_top (module)
├── clock/reset 生成
├── Interface 例化
├── DUT 例化（简单 slave RAM 或 master 模型）
├── config_db 设置（vif → agent_config → agent）
└── run_test()
```

tb 通过 `+incdir+../src` 包含 src 目录，`import hx_apb_pkg::*` 使用 VIP。

### DUT 模型

- APB TB：APB Slave RAM（接收读写，返回数据）
- AHB TB：AHB Slave RAM + 可选 AHB Master DUT

## 12. Makefile 设计

```makefile
# 环境变量（避免硬编码路径）
SIM_OUTPUT ?= $(CURDIR)/output
VCS_HOME   ?= $(VCS_HOME)

# 编译选项
COMPILE_OPTS = -sverilog -full64 -timescale=1ns/1ps
COMPILE_OPTS += +define+UVM_PACKER_MAX_BYTES=1500000
COMPILE_OPTS += +define+UVM_DISABLE_AUTO_ITEM_RECORDING
COMPILE_OPTS += +incdir+../src

# 目标
all: comp run

comp:
	vcs $(COMPILE_OPTS) -o $(SIM_OUTPUT)/simv $(TB_TOP)

run:
	$(SIM_OUTPUT)/simv +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=UVM_MEDIUM

clean:
	rm -rf $(SIM_OUTPUT) csrc *.log *.key *.vpd
```

## 13. TDD 开发流程

1. **写 feature spec MD** — 列出该模块所有支持的特性
2. **写测试** — test 定义预期行为和检查点
3. **写最小实现** — 让测试通过
4. **重构** — 清理代码，保持测试通过
5. **重复** — 下一个 feature

每个 VIP 开发前，先输出 `features.md` 文档，确认后再开发。

### 问题记录

- 开发过程中遇到的问题，通过 `to-issue` skill 记录到 GitHub Issues
- 问题分类：
  - **设计问题**：设计决策需要调整
  - **实现问题**：代码 bug 或编译错误
  - **协议问题**：对 AMBA 协议理解有误
  - **工具问题**：VCS 或 UVM 相关问题

## 14. 文件清单（按开发顺序）

### Phase 1：APB VIP

**源码（src/）：**
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

**TB（tb/）：**
14. `apb_slave_ram.sv`（DUT 模型）
15. `apb_tb_top.sv`
16. `apb_tb_pkg.sv`

**测试（test/）—— 按 feature 对应：**
17. `apb_base_test.sv` → 基础 env 配置
18. `apb_smoke_test.sv` → APB-F01, F02, F09, F12
19. `apb_random_test.sv` → APB-F05, F06
20. `apb_directed_test.sv` → APB-F13
21. `apb_wait_state_test.sv` → APB-F03
22. `apb_slverr_test.sv` → APB-F04
23. `apb_pstrb_test.sv` → APB-F10, F11
24. `apb_slave_agent_test.sv` → APB-F07
25. `apb_multi_slave_test.sv` → APB-F08

**构建（sim/）：**
26. `Makefile`
27. `.gitignore`

### Phase 2：AHB VIP

**源码（src/）：**
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

**TB（tb/）：**
16. `ahb_slave_ram.sv`（DUT 模型）
17. `ahb_tb_top.sv`
18. `ahb_tb_pkg.sv`

**测试（test/）—— 按 feature 对应：**
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

**构建（sim/）：**
30. `Makefile`
31. `.gitignore`
