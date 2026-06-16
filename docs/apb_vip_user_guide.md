# APB VIP 使用说明

## 目录

1. [概述](#1-概述)
2. [快速开始](#2-快速开始)
3. [架构说明](#3-架构说明)
4. [配置选项](#4-配置选项)
5. [验证场景](#5-验证场景)
6. [高级用法](#6-高级用法)
7. [Makefile 参数](#7-makefile-参数)
8. [常见问题](#8-常见问题)

---

## 1. 概述

APB VIP 是基于 UVM 的 APB (Advanced Peripheral Bus) 协议验证组件，支持：

- **APB3/APB4 协议**：支持 PSTRB、PPROT 等 APB4 扩展特性
- **主/从模式**：可配置为 Master 或 Slave 驱动器
- **主动/被动模式**：支持主动驱动或被动监听
- **功能覆盖**：内置覆盖率收集
- **计分板**：内存模型验证

### 文件结构

```
vip/amba/apb/
├── src/
│   ├── apb_defines.svh      // 全局参数定义
│   ├── apb_interface.sv      // APB 接口定义
│   ├── apb_transaction.sv    // 事务类
│   ├── apb_config.sv         // 配置类
│   ├── apb_agent.sv          // Agent 顶层
│   ├── apb_driver.sv         // Master 驱动器
│   ├── apb_slave_driver.sv   // Slave 驱动器
│   ├── apb_monitor.sv        // 监视器
│   ├── apb_sequences.sv      // 序列库
│   ├── apb_scoreboard.sv     // 计分板
│   └── apb_coverage.sv       // 功能覆盖
├── tb/
│   ├── apb_tb_top.sv         // Testbench 顶层
│   ├── apb_slave_ram.sv      // Slave RAM 模型
│   └── apb_tests_pkg.sv      // 测试包
├── test/
│   ├── apb_base_test.sv      // 基础测试
│   ├── apb_smoke_test.sv     // 冒烟测试
│   ├── apb_wait_state_test.sv // 等待状态测试
│   ├── apb_slverr_test.sv    // 错误注入测试
│   ├── apb_random_test.sv    // 随机测试
│   └── apb_directed_test.sv  // 定向测试
└── sim/
    └── Makefile              // 仿真脚本
```

---

## 2. 快速开始

### 2.1 运行冒烟测试

```bash
cd vip/amba/apb/sim
make clean
make run TEST=apb_smoke_test
```

### 2.2 查看结果

```bash
# 查看仿真日志
cat simv.log | grep "UVM_INFO\|UVM_ERROR\|UVM_FATAL"

# 查看覆盖率
make cov
```

---

## 3. 架构说明

### 3.1 Agent 架构

```
┌─────────────────────────────────────────────────┐
│                  apb_agent                       │
│  ┌─────────────────────────────────────────────┐ │
│  │  Active Master Mode:                        │ │
│  │    apb_driver (Master) + apb_sequencer      │ │
│  │    + apb_monitor                            │ │
│  ├─────────────────────────────────────────────┤ │
│  │  Active Slave Mode:                         │ │
│  │    apb_slave_driver + apb_sequencer         │ │
│  │    + apb_monitor                            │ │
│  ├─────────────────────────────────────────────┤ │
│  │  Passive Mode:                              │ │
│  │    apb_monitor only                         │ │
│  └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

### 3.2 APB 协议时序

```
       ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐
PCLK   │   │   │   │   │   │   │   │   │   │
     ──┘   └───┘   └───┘   └───┘   └───┘   └──

            SETUP      ACCESS
PSEL   ─────┐              ┌─────────────
             └──────────────┘

PENABLE──────┐        ┌─────────────────
             └────────┘

PREADY ──────────────┐    ┌─────────────
                     └────┘

PADDR  ─────<  A   >────────────────────
PWDATA ─────<  D   >────────────────────
```

**SETUP 阶段**：PSEL=1, PENABLE=0, PADDR/PWDATA 有效
**ACCESS 阶段**：PSEL=1, PENABLE=1, 等待 PREADY=1
**传输完成**：PREADY=1 时采样数据

---

## 4. 配置选项

### 4.1 Agent 配置 (apb_agent_config)

```systemverilog
// 在 test 或 env 的 build_phase 中配置
apb_agent_config cfg = apb_agent_config::type_id::create("cfg");

// 工作模式
cfg.is_active = UVM_ACTIVE;      // UVM_ACTIVE 或 UVM_PASSIVE
cfg.master_slave = MASTER_MODE;   // MASTER_MODE 或 SLAVE_MODE

// APB4 特性
cfg.apb4_enable = 1;             // 0=APB3, 1=APB4

// 通过 config_db 传递
uvm_config_db#(apb_agent_config)::set(this, "env.agent", "config", cfg);
```

### 4.2 系统配置 (apb_system_config)

多从设备地址映射配置：

```systemverilog
apb_system_config sys_cfg = apb_system_config::type_id::create("sys_cfg");

// 添加从设备地址范围
sys_cfg.add_slave(32'h0000_0000, 32'h0000_FFFF, "slave0");  // 64KB
sys_cfg.add_slave(32'h0001_0000, 32'h0001_FFFF, "slave1");  // 64KB

uvm_config_db#(apb_system_config)::set(this, "*", "sys_config", sys_cfg);
```

### 4.3 接口连接

```systemverilog
// 在 tb_top 中实例化接口
apb_interface apb_if(.PCLK(clk), .PRESETn(rst_n));

// 连接到 DUT
apb_slave_ram dut (
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

// 传递接口到 UVM
initial begin
    uvm_config_db#(virtual apb_interface)::set(null, "uvm_test_top.env.agent", "vif", apb_if);
end
```

---

## 5. 验证场景

### 5.1 冒烟测试 (Smoke Test)

**目的**：验证基本读写功能

```systemverilog
class apb_smoke_test extends apb_base_test;
    `uvm_component_utils(apb_smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_write_seq wr_seq;
        apb_read_seq  rd_seq;

        phase.raise_objection(this);

        // 写入数据
        wr_seq = apb_write_seq::type_id::create("wr_seq");
        wr_seq.start(env.agent.sequencer);

        // 读取并验证
        rd_seq = apb_read_seq::type_id::create("rd_seq");
        rd_seq.start(env.agent.sequencer);

        phase.drop_objection(this);
    endtask
endclass
```

运行：
```bash
make run TEST=apb_smoke_test
```

### 5.2 等待状态测试 (Wait State Test)

**目的**：验证 Slave 插入等待周期的场景

APB 协议允许 Slave 通过拉低 PREADY 插入等待状态。此测试验证：
- Master 正确等待 PREADY
- 不同等待周期数 (0-3) 的处理

```systemverilog
class apb_wait_state_test extends apb_base_test;
    `uvm_component_utils(apb_wait_state_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_rw_seq seq;
        phase.raise_objection(this);

        seq = apb_rw_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);

        phase.drop_objection(this);
    endtask
endclass
```

**关键配置**：Slave RAM 的 `WAIT_CYCLES` 参数控制等待周期数

运行（2 个等待周期）：
```bash
make run TEST=apb_wait_state_test WAIT_CYCLES=2
```

### 5.3 错误注入测试 (Slave Error Test)

**目的**：验证 Slave 返回 PSLVERR 错误响应

```systemverilog
class apb_slverr_test extends apb_base_test;
    `uvm_component_utils(apb_slverr_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_write_seq wr_seq;
        apb_read_seq  rd_seq;

        phase.raise_objection(this);

        // 错误注入时，写入和读取都应返回 PSLVERR=1
        wr_seq = apb_write_seq::type_id::create("wr_seq");
        wr_seq.start(env.agent.sequencer);

        rd_seq = apb_read_seq::type_id::create("rd_seq");
        rd_seq.start(env.agent.sequencer);

        phase.drop_objection(this);
    endtask
endclass
```

**关键配置**：Slave RAM 的 `INJECT_ERROR` 参数控制错误注入

运行：
```bash
make run TEST=apb_slverr_test INJECT_ERROR=1
```

**预期结果**：事务的 `slverr` 字段应为 1

### 5.4 随机测试 (Random Test)

**目的**：大量随机事务验证鲁棒性

```systemverilog
class apb_random_test extends apb_base_test;
    `uvm_component_utils(apb_random_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        apb_rw_seq seq;
        phase.raise_objection(this);

        // 随机序列生成多个随机读写事务
        seq = apb_rw_seq::type_id::create("seq");
        seq.num_txns = 100;  // 可配置事务数量
        seq.start(env.agent.sequencer);

        phase.drop_objection(this);
    endtask
endclass
```

运行：
```bash
make run TEST=apb_random_test
```

**事务随机化字段**：
- `addr`：32 位地址
- `data`：32 位数据
- `write`：读/写方向
- `idle_cycles`：事务间空闲周期 (0-3)
- `strb`：字节选通 (APB4)
- `prot`：保护类型 (APB4)

### 5.5 定向测试 (Directed Test)

**目的**：使用 Factory Override 测试特定场景

```systemverilog
class apb_directed_test extends apb_base_test;
    `uvm_component_utils(apb_directed_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        // 使用 Factory Override 替换序列
        uvm_factory factory = uvm_factory::get();
        factory.set_type_override_by_type(
            apb_rw_seq::get_type(),
            directed_rw_seq::get_type()
        );

        super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
        apb_rw_seq seq;  // 实际会创建 directed_rw_seq
        phase.raise_objection(this);

        seq = apb_rw_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);

        phase.drop_objection(this);
    endtask
endclass
```

运行：
```bash
make run TEST=apb_directed_test
```

### 5.6 APB4 特性测试

**目的**：验证 PSTRB 和 PPROT 扩展特性

```systemverilog
class apb_apb4_test extends apb_base_test;
    `uvm_component_utils(apb_apb4_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        // 启用 APB4
        apb_agent_config cfg;
        super.build_phase(phase);

        cfg = apb_agent_config::type_id::create("cfg");
        cfg.apb4_enable = 1;
        uvm_config_db#(apb_agent_config)::set(this, "env.agent", "config", cfg);
    endfunction

    task run_phase(uvm_phase phase);
        apb_write_seq seq;
        phase.raise_objection(this);

        seq = apb_write_seq::type_id::create("seq");
        // 设置 APB4 字段
        foreach (seq.txn[i]) begin
            seq.txn[i].strb = 4'b1010;  // 字节选通
            seq.txn[i].prot = 3'b000;   // 保护类型
        end
        seq.start(env.agent.sequencer);

        phase.drop_objection(this);
    endtask
endclass
```

---

## 6. 高级用法

### 6.1 Slave 模式配置

当验证 APB Master IP 时，VIP 配置为 Slave 模式：

```systemverilog
class my_env extends uvm_env;
    apb_agent slave_agent;

    function void build_phase(uvm_phase phase);
        apb_agent_config cfg = apb_agent_config::type_id::create("cfg");
        cfg.is_active = UVM_ACTIVE;
        cfg.master_slave = SLAVE_MODE;  // Slave 模式

        uvm_config_db#(apb_agent_config)::set(this, "slave_agent", "config", cfg);
        slave_agent = apb_agent::type_id::create("slave_agent", this);
    endfunction
endclass
```

**Slave 响应序列**：

```systemverilog
class apb_slave_response_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_slave_response_seq)

    // 响应队列
    apb_transaction resp_queue[$];

    task body();
        forever begin
            apb_transaction txn;
            // 等待 Master 请求
            p_sequencer.get_next_item(txn);

            // 生成响应
            txn.data = calculate_response(txn.addr);
            txn.slverr = check_error(txn.addr);

            p_sequencer.item_done(txn);
        end
    endtask
endclass
```

### 6.2 被动模式 (Monitor Only)

用于协议检查和覆盖率收集，不驱动信号：

```systemverilog
apb_agent_config cfg = apb_agent_config::type_id::create("cfg");
cfg.is_active = UVM_PASSIVE;  // 被动模式

uvm_config_db#(apb_agent_config)::set(this, "env.monitor_agent", "config", cfg);
```

### 6.3 计分板集成

```systemverilog
class my_env extends uvm_env;
    apb_agent     agent;
    apb_scoreboard scb;

    function void build_phase(uvm_phase phase);
        agent = apb_agent::type_id::create("agent", this);
        scb   = apb_scoreboard::type_id::create("scb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        // 连接 Monitor 到计分板
        agent.monitor.item_collected_port.connect(scb.item_collected_export);
    endfunction
endclass
```

**计分板功能**：
- 写操作：更新内部内存模型
- 读操作：比较期望值与实际值
- 错误检测：地址越界、数据不匹配

### 6.4 覆盖率收集

覆盖率自动收集，通过 `apb_coverage` 组件：

```systemverilog
// 覆盖点
// 1. 传输类型：写/读
// 2. 错误响应：PSLVERR
// 3. 空闲周期：idle_cycles
// 4. 交叉覆盖：write × slverr × idle_cycles
```

查看覆盖率报告：
```bash
make cov
# 或使用 URG
urg -dir simv.vdb -report coverage_report
```

### 6.5 自定义序列

创建自定义序列满足特定验证需求：

```systemverilog
class my_custom_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(my_custom_seq)

    // 配置参数
    int unsigned num_txns = 50;
    bit [31:0]   base_addr = 32'h0000_0000;

    task body();
        repeat (num_txns) begin
            apb_transaction txn = apb_transaction::type_id::create("txn");

            start_item(txn);
            assert(txn.randomize() with {
                addr inside {[base_addr : base_addr + 32'hFF]};
                write dist {0 := 50, 1 := 50};
                idle_cycles inside {[0:3]};
            });
            finish_item(txn);
        end
    endtask
endclass
```

---

## 7. Makefile 参数

### 7.1 基本参数

| 参数 | 说明 | 默认值 | 示例 |
|------|------|--------|------|
| `TEST` | 测试名称 | `apb_smoke_test` | `TEST=apb_random_test` |
| `SEED` | 随机种子 | `random` | `SEED=12345` |
| `VERBOSITY` | UVM 详细级别 | `UVM_MEDIUM` | `VERBOSITY=UVM_HIGH` |

### 7.2 测试特定参数

| 参数 | 说明 | 默认值 | 示例 |
|------|------|--------|------|
| `WAIT_CYCLES` | Slave 等待周期数 | `0` | `WAIT_CYCLES=3` |
| `INJECT_ERROR` | 错误注入使能 | `0` | `INJECT_ERROR=1` |

### 7.3 编译参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `UVM_HOME` | UVM 库路径 | `$VCS_HOME/etc/uvm` |
| `APB_APB4_ENABLE` | 启用 APB4 | 注释掉 |

### 7.4 常用命令

```bash
# 编译
make comp

# 运行仿真
make run TEST=apb_smoke_test

# 运行带参数的测试
make run TEST=apb_wait_state_test WAIT_CYCLES=2

# 清理
make clean

# 查看波形
make wave

# 生成覆盖率报告
make cov

# 运行回归测试
make regression
```

---

## 8. 常见问题

### 8.1 编译错误：找不到 UVM

**错误信息**：
```
Error: Cannot find UVM package
```

**解决方法**：
```bash
# 设置 VCS 环境变量
export VCS_HOME=/path/to/vcs

# 或在 Makefile 中指定
make comp UVM_HOME=/path/to/uvm
```

### 8.2 运行时错误：Virtual interface not set

**错误信息**：
```
UVM_FATAL ... Virtual interface not set for apb_agent
```

**解决方法**：确保在 `tb_top` 中正确传递接口：
```systemverilog
initial begin
    uvm_config_db#(virtual apb_interface)::set(
        null, "uvm_test_top.env.agent", "vif", apb_if
    );
end
```

### 8.3 数据不匹配

**可能原因**：
1. Slave RAM 的 PREADY 时序问题
2. PRDATA 组合逻辑/时序逻辑选择不当
3. Master 输出延迟配置

**调试方法**：
```bash
# 启用详细日志
make run TEST=apb_smoke_test VERBOSITY=UVM_DEBUG

# 查看波形
make wave
```

### 8.4 覆盖率未达到 100%

**检查点**：
1. 确认 `apb_coverage` 组件已实例化
2. 检查 Monitor 是否正确收集事务
3. 增加测试运行时间或事务数量

---

## 附录 A: APB 信号说明

| 信号 | 方向 | 说明 |
|------|------|------|
| `PCLK` | - | 时钟 |
| `PRESETn` | - | 低电平复位 |
| `PSEL` | M→S | 从设备选择 |
| `PENABLE` | M→S | 传输使能 |
| `PWRITE` | M→S | 1=写, 0=读 |
| `PADDR[31:0]` | M→S | 地址 |
| `PWDATA[31:0]` | M→S | 写数据 |
| `PRDATA[31:0]` | S→M | 读数据 |
| `PREADY` | S→M | 传输就绪 |
| `PSLVERR` | S→M | 错误响应 |
| `PSTRB[3:0]` | M→S | 字节选通 (APB4) |
| `PPROT[2:0]` | M→S | 保护类型 (APB4) |

## 附录 B: Transaction 字段

```systemverilog
class apb_transaction extends uvm_sequence_item;
    rand bit [31:0] addr;        // 地址
    rand bit [31:0] data;        // 数据
    rand bit        write;       // 1=写, 0=读
    rand int        idle_cycles; // 事务间空闲周期
    rand bit [3:0]  strb;        // 字节选通 (APB4)
    rand bit [2:0]  prot;        // 保护类型 (APB4)
    bit             slverr;      // 错误响应 (由 Slave 驱动)
endclass
```

---

*文档版本：1.0*
*最后更新：2024*
