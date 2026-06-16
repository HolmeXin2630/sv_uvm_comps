# UVM VIP 编码规范

> 参考：UVM Cookbook、Synopsys VIP 实践、UVM Best Practices

---

## 1. Sequence-Item 发送方式

### 禁止使用 `uvm_do / `uvm_do_with

这些宏隐藏了 `start_item` → `randomize` → `finish_item` 的过程，调试困难，约束不可见。

**正确做法：显式调用**

```systemverilog
task body();
    apb_transaction txn;
    txn = apb_transaction::type_id::create("txn");

    // 方式 1：先 randomize 再发
    assert(txn.randomize() with {
        txn.write == 1;
        txn.addr inside {[32'h0000_0000 : 32'h0000_FFFF]};
    }) else `uvm_fatal("RANDFAIL", "Randomize failed")

    start_item(txn);
    finish_item(txn);

    // 方式 2：start_item 后 randomize（推荐，可访问 p_sequencer）
    start_item(txn);
    assert(txn.randomize() with {
        txn.write == 1;
    }) else `uvm_fatal("RANDFAIL", "Randomize failed")
    finish_item(txn);
endtask
```

### 禁止使用 `uvm_send

直接使用 `start_item` / `finish_item`。

### 使用 `uvm_create 时需谨慎

如果使用 `uvm_create`，必须配合 `start_item` / `finish_item`：

```systemverilog
`uvm_create(txn)
start_item(txn);
assert(txn.randomize()) else `uvm_fatal("RANDFAIL", "")
finish_item(txn);
```

---

## 2. Randomize 规范

### 每次 randomize 必须检查返回值

```systemverilog
// 错误
txn.randomize();

// 正确
assert(txn.randomize()) else `uvm_fatal("RANDFAIL", $sformatf("Failed: %s", txn.convert2string()))
```

### 内联约束使用 with 语法

```systemverilog
assert(txn.randomize() with {
    txn.addr[1:0] == 2'b00;
    txn.burst == SINGLE;
}) else `uvm_fatal("RANDFAIL", "")
```

### 禁止在 class 内部约束中使用外部变量

约束应自包含，外部条件通过 config object 传递。

---

## 3. Factory 使用规范

### 所有组件必须注册 factory

```systemverilog
class apb_driver extends uvm_driver #(apb_transaction);
    `uvm_component_utils(apb_driver)
    ...
endclass

class apb_transaction extends uvm_sequence_item;
    `uvm_object_utils(apb_transaction)
    ...
endclass
```

### 创建对象必须用 type_id::create

```systemverilog
// 错误
apb_transaction txn = new("txn");

// 正确
apb_transaction txn = apb_transaction::type_id::create("txn");

// 组件同理
apb_driver drv = apb_driver::type_id::create("drv", this);
```

### 禁止使用 set_type_override / set_inst_override

除非用户明确要求，VIP 内部不使用 factory override。Override 权限交给使用 VIP 的 test。

---

## 4. Config Object 模式

### 用独立 Config Object 管理配置，不用散落的 config_db

```systemverilog
// 错误：散落传参
uvm_config_db#(int)::set(this, "agt", "addr_width", 32);
uvm_config_db#(virtual apb_if)::set(this, "agt", "vif", vif);

// 正确：封装到 config object
class apb_config extends uvm_object;
    int           addr_width = 32;
    int           data_width = 32;
    virtual apb_if vif;
    ...
endclass

uvm_config_db#(apb_config)::set(this, "agt", "cfg", cfg);
```

### Config Object 使用 uvm_object，不用 uvm_component

Config Object 是数据容器，不是组件树节点。

### 依赖注入原则（优先于 config_db）

**核心原则**：所有 cfg 应该在上一层级显式赋值，不使用 config_db 传递配置。

**config_db 使用限制**：仅限于从 tb_top 中传递 virtual interface。

```systemverilog
// 错误：使用 config_db 传递配置
uvm_config_db#(ahb_agent_config)::set(this, "agt", "cfg", cfg);
uvm_config_db#(ahb_env_config)::set(this, "env", "env_cfg", env_cfg);

// 正确：显式赋值（依赖注入）
agt.cfg = env_cfg.agent_cfg[index];
env.env_cfg = env_cfg;

// 正确：config_db 仅用于传递 virtual interface（从 tb_top）
// 使用通配符，支持多个 Agent
uvm_config_db#(virtual ahb_interface)::set(null, "*.ahb_env.mst_agt[0]", "vif", ahb_mst_if[0]);
```

### virtual interface 获取原则

**核心原则**：所有 vif get 应该在 agt 的 build_phase 中，tb_top 使用通配符设置。

**tb_top 实现**：
```systemverilog
module tb_top;
    // Interface 实例化
    ahb_interface ahb_mst_if[2]();
    ahb_interface ahb_slv_if[3]();
    
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
    
    // ... DUT 例化 ...
endmodule
```

**Agent build_phase 实现**：
```systemverilog
class ahb_master_agent extends uvm_agent;
    // ... 其他代码 ...
    
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
        // 传递 vif 给 driver 和 monitor
        drv.vif = vif;
        mon.vif = vif;
        
        if (cfg.active)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
```

### 关键点

- **tb_top**：使用通配符和 generate 块循环设置多个 vif
- **Agent build_phase**：获取 vif，传递给 driver 和 monitor
- **多通道支持**：通过 generate 块的循环支持多个 Agent

### Agent 的暴露 API

Agent 暴露给用户的 API 应该只有：
1. **顶层 cfg**：Agent 的配置对象
2. **功能 seq**：各种功能的 Sequence

```systemverilog
class ahb_master_agent extends uvm_agent;
    // 暴露给用户的 API
    ahb_agent_config cfg;  // 配置
    ahb_sequencer sqr;     // 用于启动 Sequence
    
    // 内部组件（不暴露）
    ahb_master_driver drv;
    ahb_monitor mon;
    
    function void build_phase(uvm_phase phase);
        // 使用 cfg 中的参数创建组件
        if (cfg.active) begin
            drv = ahb_master_driver::type_id::create("drv", this);
            sqr = ahb_sequencer::type_id::create("sqr", this);
        end
        mon = ahb_monitor::type_id::create("mon", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
        if (cfg.active) begin
            drv.cfg = cfg;  // 显式赋值
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction
endclass
```

### 组合原则

**核心原则**：Env 应该有 env_cfg，env_cfg 包含所有 Agent 的 cfg。

```systemverilog
class ahb_env_config extends uvm_object;
    // Agent 数量
    int master_agt_num = 1;
    int slave_agt_num  = 1;
    
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
endclass
```

### Env 中的依赖注入

```systemverilog
class ahb_bus_env extends uvm_env;
    // 暴露给用户的 API
    ahb_env_config env_cfg;  // 配置
    
    // 内部组件
    ahb_master_agent master_agt[];
    ahb_slave_agent  slave_agt[];
    
    function void build_phase(uvm_phase phase);
        // 从 config_db 获取 env_cfg（仅此一处）
        if (!uvm_config_db#(ahb_env_config)::get(this, "", "env_cfg", env_cfg))
            `uvm_fatal("NOCONFIG", "ahb_env_config not set")
        
        // 创建 Agent
        master_agt = new[env_cfg.master_agt_num];
        foreach (master_agt[i])
            master_agt[i] = ahb_master_agent::type_id::create(
                $sformatf("master_agt[%0d]", i), this);
        
        slave_agt = new[env_cfg.slave_agt_num];
        foreach (slave_agt[i])
            slave_agt[i] = ahb_slave_agent::type_id::create(
                $sformatf("slave_agt[%0d]", i), this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
        // 显式赋值 cfg（依赖注入）
        foreach (master_agt[i])
            master_agt[i].cfg = env_cfg.master_cfg[i];
        foreach (slave_agt[i])
            slave_agt[i].cfg = env_cfg.slave_cfg[i];
    endfunction
endclass
```

---

## 5. TLM 连接规范

### 组件间通过 TLM port 连接，不直接引用句柄

```systemverilog
// 错误：直接引用
mon.txn = drv.current_txn;

// 正确：通过 analysis_port
class apb_monitor extends uvm_monitor;
    uvm_analysis_port #(apb_transaction) ap;
    ...
    ap.write(txn);  // 广播
endclass
```

### connect_phase 中做连接，build_phase 中做创建

```systemverilog
function void build_phase(uvm_phase phase);
    mon = apb_monitor::type_id::create("mon", this);
endfunction

function void connect_phase(uvm_phase phase);
    mon.ap.connect(scb.analysis_export);
endfunction
```

---

## 6. Objection 管理

### Sequence 中管理 objection

```systemverilog
task body();
    uvm_phase phase = get_starting_phase();
    if (phase != null)
        phase.raise_objection(this);

    // ... 发送 transaction ...

    if (phase != null)
        phase.drop_objection(this);
endtask
```

### 只在顶层 sequence 管 objection

子 sequence 不要 raise/drop objection，由顶层统一管理。

---

## 7. 编码风格

### 命名规范

| 类型 | 风格 | 示例 |
|------|------|------|
| class | snake_case | `apb_transaction` |
| function/task | snake_case | `convert2string` |
| 变量 | snake_case | `addr_width` |
| 常量/宏 | UPPER_CASE | `APB_APB4_ENABLE` |
| enum | UPPER_CASE | `SINGLE`, `INCR4` |
| 参数 | UPPER_CASE 或 camelCase | `ADDR_WIDTH` |

### 文件组织

- 一个文件一个主要 class（与文件名同名）
- `include guard 用 `ifndef / `define / `endif
- 文件头包含简要注释说明用途

```systemverilog
// APB Transaction - 单笔 APB 传输的 sequence item
`ifndef APB_TRANSACTION_SV
`define APB_TRANSACTION_SV

class apb_transaction extends uvm_sequence_item;
    ...
endclass

`endif // APB_TRANSACTION_SV
```

### 注释

- 只在不明显的地方加注释
- 不要注释掉的代码（删掉，git 有历史）
- 中英文混用时保持一致性（本项目用英文注释）

---

## 8. Phase 使用规范

| Phase | 用途 |
|-------|------|
| `build_phase` | 创建子组件、获取 config |
| `connect_phase` | TLM port 连接 |
| `end_of_elaboration_phase` | 打印拓扑、最终配置检查 |
| `run_phase` | Driver/Monitor 的主循环 |
| `check_phase` | Scoreboard 最终检查 |
| `report_phase` | 打印统计信息 |
| `final_phase` | 关闭文件等清理工作 |

### 不在 build_phase 之外创建组件

### 不在 connect_phase 之外做 TLM 连接

---

## 9. 错误处理

### 使用 `uvm_fatal 终止仿真

不可恢复的错误（如 config 缺失、interface 未设置）：

```systemverilog
if (!uvm_config_db#(apb_config)::get(this, "", "cfg", cfg))
    `uvm_fatal("NOCONFIG", "apb_config not set")
```

### 使用 `uvm_error 报告但继续

可恢复的错误（如协议违规）：

```systemverilog
if (vif.PSLVERR)
    `uvm_error("APBERR", $sformatf("Slave error at addr=0x%08h", vif.PADDR))
```

### 不使用 `uvm_warning

要么是错误（`uvm_error），要么不是。Warning 容易被忽略。

---

## 10. 代码复用

### 优先使用组合而非继承

Agent 包含 Driver/Monitor/Sequencer（组合），而不是继承。

### Sequence 通过 p_sequencer 访问上下文

```systemverilog
class apb_sequence extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_sequence)

    // 不要用 `uvm_declare_p_sequencer 宏
    // 直接在 body 中通过 start 的 sequencer 参数访问
    virtual task body();
        apb_sequencer sqr;
        if (!$cast(sqr, m_sequencer))
            `uvm_fatal("CAST", "Failed to cast sequencer")
        // 使用 sqr 访问 sequencer 上的信息
    endtask
endclass
```
