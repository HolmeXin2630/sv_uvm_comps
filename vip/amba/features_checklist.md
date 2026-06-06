# AMBA VIP Feature Checklist

> TDD 执行阶段使用，每个 feature 对应至少一个测试，完成后打勾。

---

## APB 协议特性

### APB3 基础特性

- [ ] **APB-F01** 基本写传输 — `apb_smoke_test`
- [ ] **APB-F02** 基本读传输 — `apb_smoke_test`
- [ ] **APB-F03** PREADY=0 等待 — `apb_wait_state_test`
- [ ] **APB-F04** PSLVERR 错误响应 — `apb_slverr_test`
- [ ] **APB-F05** 连续传输（back-to-back） — `apb_random_test`
- [ ] **APB-F06** Idle cycles 可配置 — `apb_random_test`
- [ ] **APB-F07** Slave Agent 驱动 — `apb_slave_agent_test`
- [ ] **APB-F08** 多 Slave 地址译码 — `apb_multi_slave_test`
- [ ] **APB-F09** Passive 模式（Monitor only） — `apb_smoke_test`

### APB4 扩展特性

- [ ] **APB-F10** PSTRB 字节选通 — `apb_pstrb_test`
- [ ] **APB-F11** PPROT 保护类型 — `apb_pstrb_test`
- [ ] **APB-F12** 无 PSTRB 时默认全选通 — `apb_smoke_test`

### 通用特性

- [ ] **APB-F13** Factory override — `apb_directed_test`
- [ ] **APB-F14** Config Object 模式 — 所有测试

---

## AHB 协议特性

### AHB 基础特性

- [ ] **AHB-F01** SINGLE 传输 — `ahb_lite_test`, `ahb_burst_size_test`
- [ ] **AHB-F02** INCR burst（不定长） — `ahb_burst_test`
- [ ] **AHB-F03** INCR4/8/16 burst — `ahb_burst_test`
- [ ] **AHB-F04** WRAP4/8/16 burst — `ahb_burst_test`
- [ ] **AHB-F05** HREADY=0 等待 — `ahb_wait_state_test`
- [ ] **AHB-F06** HRESP=ERROR 错误响应 — `ahb_error_resp_test`
- [ ] **AHB-F07** HMASTLOCK 锁定传输 — `ahb_mastlock_test`
- [ ] **AHB-F08** 不同 burst_size — `ahb_burst_size_test`
- [ ] **AHB-F09** BUSY 传输 — `ahb_busy_test`
- [ ] **AHB-F10** IDLE 传输 — `ahb_random_test`（隐式覆盖）
- [ ] **AHB-F11** Pipeline 重叠 — `ahb_pipeline_test`
- [ ] **AHB-F12** Slave Agent 响应 — `ahb_slave_test`
- [ ] **AHB-F13** Slave 内存模型 — `ahb_slave_test`
- [ ] **AHB-F18** HPROT 保护信号 — `ahb_burst_test`

### AHB-Lite 特性

- [ ] **AHB-F14** 单 Master 模式 — `ahb_lite_test`
- [ ] **AHB-F20** Passive 模式 — `ahb_lite_test`

### Full AHB 特性

- [ ] **AHB-F15** 多 Master 仲裁 — `ahb_full_bus_test`
- [ ] **AHB-F16** HBUSREQ/HGRANT 信号 — `ahb_full_bus_test`
- [ ] **AHB-F17** Default Slave（越界 ERROR） — `ahb_full_bus_test`
- [ ] **AHB-F19** Slave 地址译码 — `ahb_full_bus_test`

### 通用特性

- [ ] **AHB-F21** Factory override — 所有测试
- [ ] **AHB-F22** Config Object 模式 — 所有测试

---

## 统计

| 协议 | 总特性数 | 已完成 | 进度 |
|------|----------|--------|------|
| APB  | 14       | 0      | 0%   |
| AHB  | 22       | 0      | 0%   |
| 合计 | 36       | 0      | 0%   |
