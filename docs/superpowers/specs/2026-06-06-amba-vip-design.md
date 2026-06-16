# AMBA APB & AHB VIP 设计文档

> 日期：2026-06-06（更新于 2026-06-16）
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

### 1.1 设计决策：AHB Transaction 粒度

**选择 Beat-level Transaction（遵循 UVM Cookbook）**

| 方案 | Transaction 粒度 | Driver 复杂度 | Pipeline 实现 | 调试难度 |
|------|------------------|---------------|---------------|----------|
| **Beat-level（采用）** | 单拍 | 简单无状态 | 天然支持 | 简单 |
| Burst-level（VCS VIP） | 整个 burst | 复杂（需内部拆分） | 需要 FIFO 同步 | 复杂 |

**理由**：
1. **Driver 简单**：无需内部维护 beat 索引和 burst 状态机
2. **Pipeline 天然支持**：address_thread 和 data_thread 直接处理单拍，通过 mailbox 同步
3. **错误处理灵活**：每拍独立，Sequence 可根据响应决定是否继续
4. **调试容易**：每拍独立 transaction，错误定位精确
5. **符合 UVM Cookbook 推荐**：pipelined bus 协议使用 beat-level transaction

**代价**：Sequence 需要循环发送 beat，但这可以通过 Sequence Library 封装，对用户透明。

### 1.2 设计原则

1. **依赖注入**：所有 cfg 显式赋值，不使用 config_db 传递
2. **组合原则**：env_cfg 包含所有 Agent 的 cfg
3. **config_db 限制**：仅限于从 tb_top 传递 vif
4. **Beat-level Transaction**：遵循 UVM Cookbook，Driver 简单
5. **双 analysis_port**：Monitor 同时提供 beat 级和 burst 级数据
6. **分层 Coverage**：Agent 级 + 跨 Agent Coverage
7. **动态创建**：Env 通过 env_cfg 中的 num 动态创建 Agent

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
│   │   ├── apb_slave_ram.sv        # DUT 模型（可配置 wait states 和错误注入）
│   │   ├── apb_tb_top.sv           # module test_top
│   │   └── apb_tb_pkg.sv           # tb 专用 package
│   ├── test/
│   │   ├── apb_base_test.sv        # base_test（默认配置）
│   │   ├── apb_smoke_test.sv
│   │   ├── apb_random_test.sv
│   │   ├── apb_directed_test.sv
│   │   ├── apb_wait_state_test.sv
│   │   ├── apb_slverr_test.sv
│   │   ├── apb_pstrb_test.sv
│   │   ├── apb_slave_agent_test.sv
│   │   └── apb_multi_slave_test.sv
│   └── sim/
│       ├── Makefile                # 一个 Makefile，通过变量控制 Test
│       └── .gitignore
│
└── ahb/
    ├── src/
    │   ├── ahb_defines.svh         # 宏定义（宽度、版本控制）
    │   ├── ahb_interface.sv        # 接口（含 clocking block）
    │   ├── ahb_transaction.sv      # Transaction（beat-level，data[] 队列）
    │   ├── ahb_agent_config.sv     # Agent 配置（单个 Agent）
    │   ├── ahb_env_config.sv       # Env 配置（包含 Agent 配置数组）
    │   ├── ahb_sequencer.sv        # Sequencer（含 request_fifo）
    │   ├── ahb_monitor.sv          # Monitor（双 analysis_port：beat_ap + burst_ap）
    │   ├── ahb_master_driver.sv    # Master Driver（pipeline：address_thread + data_thread）
    │   ├── ahb_slave_driver.sv     # Slave Driver（检测有效传输，插入 wait states）
    │   ├── ahb_master_agent.sv     # Master Agent（含 vif 获取、依赖注入）
    │   ├── ahb_slave_agent.sv      # Slave Agent（含 Monitor→Sequence FIFO）
    │   ├── ahb_bus_env.sv          # Env（动态创建 Agent、依赖注入）
    │   ├── ahb_sequences.sv        # Sequence 库（含 burst 地址计算）
    │   ├── ahb_agent_coverage.sv   # Agent 级 Coverage
    │   ├── ahb_cross_coverage.sv   # 跨 Agent Coverage
    │   ├── ahb_scoreboard.sv       # Scoreboard（burst 级比对）
    │   ├── ahb_slave_ram.sv        # DUT 模型（可配置 wait states 和错误注入）
    │   └── ahb_pkg.sv              # Package 封装
    ├── tb/
    │   ├── ahb_tb_top_lite.sv      # tb_top（AHB-Lite 模式）
    │   ├── ahb_tb_top_burst.sv     # tb_top（Burst 测试）
    │   ├── ahb_tb_top_wait.sv      # tb_top（Wait State 测试）
    │   ├── ahb_tb_top_error.sv     # tb_top（错误响应测试）
    │   ├── ahb_tb_top_pipeline.sv  # tb_top（Pipeline 测试）
    │   ├── ahb_tb_top_slave.sv     # tb_top（Slave Agent 测试）
    │   ├── ahb_tb_top_full_bus.sv  # tb_top（Full AHB 测试）
    │   └── ahb_tb_pkg.sv           # TB package
    ├── test/
    │   ├── ahb_base_test.sv        # base_test（默认配置）
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
        ├── Makefile                # 一个 Makefile，通过变量控制 Test
        └── .gitignore
```

## 3. 命名规范

- Package 前缀：`hx_`（如 `hx_apb_pkg`、`hx_ahb_pkg`）
- Package 内部类名不加前缀（如 `apb_transaction`、`ahb_driver`）
- 使用时：`import hx_apb_pkg::*;` 或 `hx_apb_pkg::apb_transaction`

## 3.1 AHB Transaction 设计决策

**采用 Beat-level Transaction（遵循 UVM Cookbook）**

| 维度 | Beat-level（采用） | Burst-level（VCS VIP） |
|------|-------------------|------------------------|
| Transaction 语义 | 单拍（beat） | 完整 burst |
| Driver 复杂度 | 简单无状态 | 复杂（需内部拆分） |
| Pipeline 实现 | 天然支持 | 需要 FIFO 同步 |
| Sequence 复杂度 | 需要循环发送 | 一次发送 |
| 错误处理 | 每拍独立，灵活 | 整个 burst，不灵活 |
| 与 VCS VIP 对齐 | ❌ 不一致 | ✅ 一致 |

**理由**：
1. Driver 简单，无需维护 beat 索引和 burst 状态机
2. Pipeline 天然支持，address_thread 和 data_thread 直接处理单拍
3. 错误处理灵活，每拍独立，Sequence 可根据响应决定是否继续
4. 符合 UVM Cookbook 推荐：pipelined bus 协议使用 beat-level transaction

**详细设计见 `CONTEXT.md`**

## 3.2 Interface 设计

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

### 6.2 AHB Transaction（Beat-level，遵循 UVM Cookbook）

**单一类型，灵活使用**：同一个 `ahb_transaction` 类型，通过 `data[]` 队列长度区分 beat/burst。

| 字段 | 类型 | 说明 | 填充来源 |
|---|---|---|---|
| `xact_type` | `xact_type_e` | READ / WRITE | Sequence / Monitor |
| `addr` | `bit [ADDR_WIDTH-1:0]` | 当前拍地址 | Sequence / Monitor |
| `burst_type` | `hburst_e` | burst 类型（首拍有效） | Sequence / Monitor |
| `burst_size` | `hsize_e` | 8/16/32/64/... bit | Sequence / Monitor |
| `data[]` | `bit [DATA_WIDTH-1:0]` | 数据队列（beat 时长度 1，burst 时长度 N） | Sequence / Monitor |
| `prot` | `bit [3:0]` | 保护类型 | Sequence / Monitor |
| `hresp` | `hresp_e` | 响应（OKAY/ERROR） | Slave Driver / Monitor |
| `wait_cycles` | `int unsigned` | 等待周期（Slave 专用） | Slave Sequence |
| `beat_num` | `int unsigned` | 当前是第几拍（上下文） | Sequence / Monitor |
| `burst_length` | `int unsigned` | burst 总拍数（上下文） | Sequence / Monitor |
| `is_first_beat` | `bit` | 是否首拍（上下文） | Sequence / Monitor |
| `is_last_beat` | `bit` | 是否末拍（上下文） | Sequence / Monitor |

**数据队列使用规则**：

| 场景 | `data[]` 长度 | 说明 |
|------|---------------|------|
| Driver 从 Sequencer 获取 | 1 | 单拍驱动 |
| Slave Sequence 生成响应 | 1 | 单拍响应 |
| Monitor `beat_ap` 发送 | 1 | 逐拍采集 |
| Monitor `burst_ap` 发送 | N | burst 完整数据 |

**关键方法**：
- `get_transfer_size()` — 返回单次传输字节数（根据 burst_size）
- `get_beat_addr(int beat)` — 返回第 N 拍地址（支持 WRAP 计算）
- `calc_next_addr()` — 根据当前地址和 burst 类型计算下一拍地址

**WRAP 地址计算**：在 Transaction 方法中实现，复用性好。

## 7. Config 设计

### 7.1 设计原则

- **依赖注入**：所有 cfg 显式赋值，不使用 config_db 传递
- **组合原则**：env_cfg 包含所有 Agent 的 cfg
- **config_db 限制**：仅限于从 tb_top 传递 vif

### 7.2 Config 层级

```
ahb_env_config
├── master_agt_num / slave_agt_num
├── master_cfg[]  (ahb_agent_config)
├── slave_cfg[]   (ahb_agent_config)
└── slave_addr_map[]
```

### 7.3 APB Config

- `apb_agent_config`：`active`、`apb4_enable`、`addr_width`、`data_width`、`vif`、功能开关
- `apb_system_config`：`num_slaves`、`master_cfg`、`slave_cfg[]`、`slave_addr_map[]`

### 7.4 AHB Config

- `ahb_agent_config`：`active`、`ahb5_enable`、`addr_width`、`data_width`、`vif`、功能开关
- `ahb_env_config`：`ahb_lite`、`master_agt_num`、`slave_agt_num`、`master_cfg[]`、`slave_cfg[]`、`slave_addr_map[]`

AHB-Lite 快捷初始化：`init_lite()` 设 `master_agt_num=1`。

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

### 8.3 Agent 暴露 API

Agent 暴露给用户的 API 应该只有：
1. **cfg**：Agent 的配置对象
2. **sqr**：Sequencer（用于启动 Sequence）

### 8.4 Agent vif 获取

**设计决策**：所有 vif get 应该在 agt 的 build_phase 中，tb_top 使用通配符设置。

**tb_top 实现**：
```systemverilog
// 使用 generate 块循环设置 vif
genvar i;
generate
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
endgenerate
```

**Agent build_phase 实现**：
```systemverilog
function void build_phase(uvm_phase phase);
    // 从 config_db 获取 vif
    if (!uvm_config_db#(virtual ahb_interface)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", $sformatf("vif not set for %s", get_full_name()))
endfunction
```

### 8.5 Slave Agent 内部连接（Monitor → Sequence 通知机制）

**连接 `beat_ap`**：Slave 逐拍响应，可以插入 wait states 或提前返回 ERROR。

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
DUT 发起传输 → Slave Monitor 观测 → beat_ap.write(txn)  [逐拍]
    → sqr.request_fifo → Slave Sequence: get(req)  [逐拍获取]
    → 生成响应 → start_item/finish_item → Slave Driver 驱动回 DUT  [逐拍响应]
```

### 8.6 Driver 行为

**APB Master Driver FSM：**
1. Idle cycles → SETUP（PSEL=1, PENABLE=0, 驱动 PADDR/PWRITE/PWDATA）
2. ACCESS（PENABLE=1）→ 等待 PREADY=1 → 采样 PRDATA/PSLVERR → IDLE

**APB Slave Driver：**
1. 等待 PSEL=1 → 从 sequencer 获取响应 → 驱动 PRDATA/PREADY/PSLVERR

**AHB Master Driver（Beat-level，遵循 UVM Cookbook）：**
1. 从 Sequencer 获取单拍 transaction
2. Address thread：驱动 HADDR/HTRANS/HWRITE/HSIZE/HBURST，等待 HREADY
3. Data thread：写操作驱动 HWDATA，读操作采样 HRDATA，等待 HREADY
4. **Pipeline 天然支持**：address_thread 和 data_thread 通过 mailbox 同步，可以同时工作
5. **无需内部拆分**：每拍一个 transaction，Driver 简单无状态

**AHB Slave Driver（Beat-level）：**
1. 检测有效传输（NONSEQ/SEQ）→ 从 sequencer 获取单拍响应
2. 插入 wait states（HREADY=0）→ 驱动 HREADY=1 + HRDATA/HRESP
3. **无需内部维护 beat 索引**：每拍一个 transaction

### 8.7 Monitor 行为

**APB Monitor：**
1. 检测 SETUP（PSEL=1, PENABLE=0）→ 采样地址
2. 等 ACCESS 完成（PREADY=1）→ 采样数据 → `ap.write(txn)`

**AHB Monitor（Beat-level，双 analysis_port）：**
1. **双 port**：
   - `beat_ap`：逐拍发送（给 coverage、slave response sequence）
   - `burst_ap`：burst 完成后组装发送（给 scoreboard）
2. **逐拍采集**：检测有效传输（NONSEQ/SEQ + HREADY=1）→ 采样地址/数据/响应
3. **burst 组装**：内部维护 burst 状态，burst 完成后通过 `burst_ap` 发送
4. **INCR 处理**：检测到新的 NONSEQ 或 IDLE 时发送上一个 INCR burst

### 8.8 Active/Passive 切换

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

### 9.2 AHB Sequences（Beat-level）

**设计要点**：每个 transaction 代表一拍，Sequence 负责 burst 管理。

| Sequence | 说明 |
|---|---|
| `ahb_single_write_seq` | 单笔 SINGLE 写（1 拍） |
| `ahb_single_read_seq` | 单笔 SINGLE 读（1 拍） |
| `ahb_burst_write_seq` | Burst 写（循环发送 beat，计算每拍地址） |
| `ahb_burst_read_seq` | Burst 读（循环发送 beat，计算每拍地址） |
| `ahb_random_rw_seq` | 随机读写（单拍或多拍） |
| `ahb_slave_response_seq` | Slave 响应（forever 循环，每拍响应） |

### 9.3 Objection 管理策略

**设计决策**：只在顶层 Sequence 管理 objection，子 Sequence 不管理。

```systemverilog
// 顶层 Sequence：管理 objection
class ahb_top_test_seq extends uvm_sequence #(ahb_transaction);
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
```

## 10. Coverage 设计

### 10.1 分层设计

- **Agent 级 Coverage**：每个 Agent 一个实例，覆盖该 Agent 的特性
- **跨 Agent Coverage**：一个实例，覆盖跨 Agent 交叉特性

### 10.2 Coverage 连接

```
Master Agent 0 Coverage  ← Master 0 Monitor beat_ap/burst_ap
Master Agent 1 Coverage  ← Master 1 Monitor beat_ap/burst_ap
Slave Agent 0 Coverage   ← Slave 0 Monitor beat_ap/burst_ap
Slave Agent 1 Coverage   ← Slave 1 Monitor beat_ap/burst_ap
Slave Agent 2 Coverage   ← Slave 2 Monitor beat_ap/burst_ap

Cross-Agent Coverage     ← 所有 Monitor beat_ap/burst_ap
```

### 10.3 覆盖点

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

## 11. Scoreboard 设计

### 11.1 设计决策

- **连接 `burst_ap`**：比对 burst 级数据，完整验证
- **统一比对逻辑**：所有 burst 类型（SINGLE/INCR/WRAP）使用相同比对逻辑

### 11.2 Scoreboard 连接

```
Master Monitor burst_ap → Scoreboard.master_export
Slave Monitor burst_ap  → Scoreboard.slave_export
```

### 11.3 比对逻辑

| 检查项 | 说明 |
|--------|------|
| `burst_type` | burst 类型必须一致 |
| `addr` | 起始地址必须一致 |
| `data.size()` | 数据长度必须一致 |
| `data[i]` | 逐拍数据必须一致 |

## 12. Env 设计

### 12.1 设计决策

- **依赖注入**：所有 cfg 显式赋值，不使用 config_db 传递
- **组合原则**：env_cfg 包含所有 Agent 的 cfg
- **动态创建**：根据 env_cfg 中的 num 动态创建 Agent

### 12.2 Env 实现

```systemverilog
class ahb_bus_env extends uvm_env;
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
        
        // 创建 Scoreboard 和 Coverage
        // ...
    endfunction
    
    function void connect_phase(uvm_phase phase);
        // 显式赋值 cfg（依赖注入）
        foreach (master_agt[i])
            master_agt[i].cfg = env_cfg.master_cfg[i];
        foreach (slave_agt[i])
            slave_agt[i].cfg = env_cfg.slave_cfg[i];
        
        // 连接 Scoreboard 和 Coverage
        // ...
    endfunction
endclass
```

## 13. Testbench 结构

### 13.1 Test 结构设计

**设计决策**：tb_top + base_test 继承，每个 Test 有独立的 tb_top 配置 DUT 参数。

**Test 继承结构**：
```
ahb_base_test
├── ahb_lite_test（AHB-Lite 模式）
├── ahb_burst_test（Burst 测试）
├── ahb_pipeline_test（Pipeline 测试）
├── ahb_wait_state_test（Wait State 测试）
├── ahb_error_resp_test（错误响应测试）
└── ...
```

### 13.2 base_test 实现

```systemverilog
class ahb_base_test extends uvm_test;
    ahb_bus_env env;
    ahb_env_config env_cfg;
    
    function void build_phase(uvm_phase phase);
        // 创建 env_cfg
        env_cfg = ahb_env_config::type_id::create("env_cfg");
        env_cfg.init();
        
        // 创建 Env
        env = ahb_bus_env::type_id::create("env", this);
        
        // 显式赋值 cfg（依赖注入）
        env.env_cfg = env_cfg;
    endfunction
endclass
```

### 13.3 子 Test 实现

```systemverilog
class ahb_wait_state_test extends ahb_base_test;
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // 覆盖配置
        env_cfg.master_agt_num = 1;
        env_cfg.slave_agt_num  = 1;
        env_cfg.slave_cfg[0].wait_cycles = 2;
        
        // 显式赋值 cfg（依赖注入）
        env.env_cfg = env_cfg;
    endfunction
    
    task run_phase(uvm_phase phase);
        ahb_burst_write_seq seq;
        
        phase.raise_objection(this);
        
        seq = ahb_burst_write_seq::type_id::create("seq");
        seq.start(env.master_agt[0].sqr);
        
        #100;
        phase.drop_objection(this);
    endtask
endclass
```

### 13.4 tb_top 实现

```systemverilog
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
    ) dut (...);
    
    // vif 设置
    initial begin
        uvm_config_db#(virtual ahb_interface)::set(
            null, "*.ahb_env.mst_agt[0]", "vif", ahb_mst_if[0]);
        uvm_config_db#(virtual ahb_interface)::set(
            null, "*.ahb_env.slv_agt[0]", "vif", ahb_slv_if[0]);
    end
    
    // 启动测试
    initial begin
        run_test("ahb_wait_state_test");
    end
endmodule
```

### 13.5 DUT 模型

**设计决策**：可配置 Slave RAM，支持 wait states 和错误响应。

```systemverilog
module ahb_slave_ram #(
    parameter WAIT_CYCLES = 0,
    parameter INJECT_ERROR = 0
) (...);
    // 通过参数控制 wait states 和错误注入
endmodule
```

## 14. Makefile 设计

### 14.1 设计决策

- APB 和 AHB 各有独立 Makefile
- **一个 Makefile，通过变量控制 Test**：复用性好，避免重复

### 14.2 Makefile 模板

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

# 目标
all: comp run

comp:
	vcs $(COMPILE_OPTS) -o $(SIM_OUTPUT)/simv \
		../tb/ahb_tb_top_$(TEST).sv \
		../test/ahb_base_test.sv \
		../test/$(TEST).sv

run:
	$(SIM_OUTPUT)/simv +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=UVM_MEDIUM

clean:
	rm -rf $(SIM_OUTPUT) csrc *.log *.key *.vpd *.vdb
```

### 14.3 使用示例

```bash
# 运行默认测试
make

# 运行指定测试
make TEST=ahb_burst_test

# 运行带参数的测试
make TEST=ahb_wait_state_test WAIT_CYCLES=4

# 运行带错误注入的测试
make TEST=ahb_error_resp_test INJECT_ERROR=1
```

## 15. TDD 开发流程

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

## 16. 文件清单（按开发顺序）

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
14. `apb_slave_ram.sv`（DUT 模型，可配置 wait states 和错误注入）
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

**TB（tb/）：**
19. `ahb_tb_top_lite.sv` — tb_top（AHB-Lite 模式）
20. `ahb_tb_top_burst.sv` — tb_top（Burst 测试）
21. `ahb_tb_top_wait.sv` — tb_top（Wait State 测试）
22. `ahb_tb_top_error.sv` — tb_top（错误响应测试）
23. `ahb_tb_top_pipeline.sv` — tb_top（Pipeline 测试）
24. `ahb_tb_top_slave.sv` — tb_top（Slave Agent 测试）
25. `ahb_tb_top_full_bus.sv` — tb_top（Full AHB 测试）
26. `ahb_tb_pkg.sv` — TB package

**测试（test/）：**
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

**构建（sim/）：**
38. `Makefile` — 一个 Makefile，通过变量控制 Test 和参数
39. `.gitignore`
