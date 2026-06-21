# APB UVC (Universal Verification Component)

## Overview

This is a reusable UVM-based verification component for the AMBA APB (Advanced Peripheral Bus) protocol. It provides a complete verification environment including master/slave agents, driver, monitor, sequencer, scoreboard, and coverage collection.

## Features

- ✅ **Full APB Protocol Support**: Implements APB3/APB4 protocol specifications
- ✅ **Master/Slave Modes**: Supports both master and slave configurations
- ✅ **Reset Handling**: Proper reset-aware driver and monitor
- ✅ **Protocol Checking**: Concurrent assertions for protocol compliance
- ✅ **Functional Coverage**: Comprehensive coverage collection
- ✅ **Scoreboard**: Memory-based transaction checking
- ✅ **Sequence Library**: Various stimulus generation sequences
- ✅ **Configurable**: Parameterized for different bus widths

## Directory Structure

```
apb/
├── src/                    # Source files
│   ├── apb_defines.svh     # Width macros
│   ├── apb_interface.sv    # Interface definition
│   ├── apb_pkg.sv          # Package file
│   ├── apb_transaction.sv  # Transaction class
│   ├── apb_config.sv       # Configuration objects
│   ├── apb_sequencer.sv    # Sequencer
│   ├── apb_driver.sv       # Master driver
│   ├── apb_slave_driver.sv # Slave driver
│   ├── apb_monitor.sv      # Monitor
│   ├── apb_agent.sv        # Agent
│   ├── apb_sequences.sv    # Sequence library
│   ├── apb_coverage.sv     # Coverage collector
│   └── apb_scoreboard.sv   # Scoreboard
├── tb/                     # Testbench files
│   ├── apb_slave_ram.sv    # Slave RAM model
│   ├── apb_tb_pkg.sv       # Testbench package
│   └── apb_tb_top.sv       # Testbench top
├── test/                   # Test cases
│   ├── apb_base_test.sv    # Base test
│   ├── apb_smoke_test.sv   # Smoke test
│   ├── apb_directed_test.sv # Directed test
│   ├── apb_random_test.sv  # Random test
│   ├── apb_slverr_test.sv  # Slave error test
│   ├── apb_wait_state_test.sv # Wait state test
│   └── apb_reset_test.sv   # Reset test
├── sim/                    # Simulation directory
│   └── Makefile            # Build and run scripts
├── docs/                   # Documentation
│   └── ic-verifier/        # IC verifier documentation
│       └── env-builder/    # Environment builder docs
│           ├── DEVELOPMENT_PLAN.md
│           ├── IMPROVEMENTS.md
│           ├── VERIFICATION_REPORT.md
│           └── FINAL_SUMMARY.md
├── .ic-verifier.yml        # Project configuration
└── README.md               # This file
```

## Quick Start

### Prerequisites

- Synopsys VCS simulator
- UVM 1.2 library (included with VCS)

### Running Tests

1. **Navigate to simulation directory:**
   ```bash
   cd sim
   ```

2. **Run single test:**
   ```bash
   make comp
   make run TEST=apb_smoke_test
   ```

3. **Run regression:**
   ```bash
   make regression
   ```

4. **Run comprehensive verification (recommended):**
   ```bash
   make verify
   ```

5. **Clean build:**
   ```bash
   make clean
   ```

### Verification Methods

| Method | Command | Description |
|--------|---------|-------------|
| `make regression` | Basic regression | Checks UVM errors only |
| `make verify` | Comprehensive verification | Checks ALL error types (UVM, assertion, simulation) |

**Important:** Always use `make verify` for final verification to catch assertion errors that may not be captured by UVM error reporting.

### Verification Script

The `verify_regression.sh` script provides comprehensive verification:

```bash
# Run comprehensive verification
make verify

# Or run directly
./verify_regression.sh
```

**What it checks:**
- ✅ UVM errors and fatals
- ✅ Assertion errors (reported via `$error` system task)
- ✅ Simulation errors
- ✅ License errors
- ✅ Compilation errors
- ✅ Test completion

**Why comprehensive verification is needed:**
- Assertion errors use `$error` system task, not `uvm_error`
- UVM report server doesn't capture assertion errors
- Basic regression may produce false passes
- Comprehensive verification catches all error types

### Test Cases

| Test | Description |
|------|-------------|
| `apb_smoke_test` | Basic write/read functionality |
| `apb_directed_test` | Directed write/read scenarios |
| `apb_random_test` | Random transaction generation |
| `apb_slverr_test` | Slave error injection |
| `apb_wait_state_test` | Wait state handling |
| `apb_reset_test` | Reset handling verification |

## Usage

### Instantiation

```systemverilog
// In your testbench
import hx_apb_pkg::*;

// Create agent
apb_agent apb_agt;

// In build_phase
apb_agt = apb_agent::type_id::create("apb_agt", this);

// Configure
apb_agt.cfg = apb_agent_config::type_id::create("cfg");
apb_agt.cfg.active = 1;        // Active mode (with driver)
apb_agt.cfg.master_mode = 1;   // Master mode
```

### Running Sequences

```systemverilog
// Write sequence
apb_write_seq wr_seq = apb_write_seq::type_id::create("wr_seq");
wr_seq.addr = 'h100;
wr_seq.data = 'hDEADBEEF;
wr_seq.start(apb_agt.sqr);

// Read sequence
apb_read_seq rd_seq = apb_read_seq::type_id::create("rd_seq");
rd_seq.addr = 'h100;
rd_seq.start(apb_agt.sqr);

// Random sequence
apb_rw_seq rw_seq = apb_rw_seq::type_id::create("rw_seq");
rw_seq.num_txns = 100;
rw_seq.start(apb_agt.sqr);
```

### Configuration

```systemverilog
// Agent configuration
apb_agent_config cfg = apb_agent_config::type_id::create("cfg");
cfg.active = 1;           // 1=active, 0=passive
cfg.master_mode = 1;      // 1=master, 0=slave
cfg.addr_width = 32;      // Address width
cfg.data_width = 32;      // Data width
cfg.apb4_enable = 0;      // APB4 features

// System configuration
apb_system_config sys_cfg = apb_system_config::type_id::create("sys_cfg");
sys_cfg.num_slaves = 1;
sys_cfg.init();
```

## Verification

### Coverage

The UVC collects functional coverage on:
- Write/read operations
- Address ranges (low/mid/high)
- Data patterns (zero/ones/walking)
- Cross coverage for important combinations
- Slave error scenarios

### Protocol Checks

Concurrent assertions verify:
- Signal stability during access phase
- Proper PENABLE/PREADY sequencing
- APB protocol compliance

### Scoreboard

The scoreboard provides:
- Memory-based transaction checking
- Read data verification
- Slave error tracking
- Match/mismatch reporting

## Customization

### Adding Custom Tests

1. Create new test file in `test/` directory
2. Extend `apb_base_test`
3. Add to `tb/apb_tb_pkg.sv`
4. Run with `make run TEST=your_test`

### Adding Custom Sequences

1. Create new sequence in `src/apb_sequences.sv`
2. Extend `uvm_sequence#(apb_transaction)`
3. Implement `body()` task
4. Register with factory

### Parameterization

Modify `src/apb_defines.svh` for bus width changes:
```systemverilog
`define APB_ADDR_WIDTH 32
`define APB_DATA_WIDTH 32
```

## Troubleshooting

### Common Issues

1. **Compilation Errors**: Ensure UVM_HOME is correctly set in Makefile
2. **License Issues**: Check SNPSLMD_LICENSE_FILE environment variable
3. **Test Failures**: Review UVM report messages for details

### Debug Tips

1. Use `+UVM_VERBOSITY=UVM_HIGH` for detailed messages
2. Check waveform for signal-level debugging
3. Review coverage reports for coverage holes

## References

- AMBA APB Protocol Specification
- UVM 1.2 User Guide
- Synopsys VCS User Guide

## Support

For issues or questions:
1. Check the documentation
2. Review test examples
3. Consult UVM best practices

## License

This UVC is provided as-is for verification purposes. Modify and extend as needed for your project.
