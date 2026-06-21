# APB UVC Verification Guide

## Overview

This guide describes the verification methodology for the APB UVC, including how to avoid false passes when using assertions.

## Verification Methods

### 1. Basic Regression (`make regression`)

**Purpose:** Quick check for UVM errors only

**Command:**
```bash
make regression
```

**What it checks:**
- UVM errors (`UVM_ERROR`)
- UVM fatals (`UVM_FATAL`)
- Test completion

**Limitations:**
- ❌ Does NOT check assertion errors
- ❌ Does NOT check simulation errors
- ❌ May produce false passes

**Use when:**
- Quick development checks
- When no assertions are present
- For initial debugging

### 2. Comprehensive Verification (`make verify`)

**Purpose:** Thorough verification checking ALL error types

**Command:**
```bash
make verify
```

**What it checks:**
- ✅ UVM errors and fatals
- ✅ Assertion errors (`Error:.*assert`)
- ✅ Simulation errors (`^Error:`)
- ✅ License errors
- ✅ Compilation errors
- ✅ Test completion

**Use when:**
- Final verification before commit
- When assertions are present
- For production verification

## Verification Script

### verify_regression.sh

The comprehensive verification script checks for all error types:

```bash
#!/bin/bash
# Checks for:
# - UVM errors and fatals
# - Assertion errors
# - Simulation errors
# - License errors
# - Compilation errors
# - Test completion
```

### Script Features

1. **Color-coded output**
   - Green: PASS
   - Red: FAIL
   - Yellow: Warnings

2. **Detailed error reporting**
   - Shows specific error messages
   - Identifies error type
   - Provides context

3. **Comprehensive checking**
   - All error types
   - Test completion verification
   - Summary statistics

## Assertion Verification

### Problem: False Passes

When using concurrent assertions, it's possible to get false passes:

```
UVM Report Summary:
UVM_ERROR :    0
UVM_FATAL :    0

# But simulation output contains:
Error: "../src/apb_interface.sv", 94: Assertion failed
```

### Root Cause

- Assertion errors use `$error` system task
- UVM report server doesn't capture `$error` messages
- Basic regression only checks UVM errors

### Solution

1. **Use comprehensive verification**
   ```bash
   make verify
   ```

2. **Check all error types**
   ```bash
   # Manual check
   make run TEST=apb_smoke_test 2>&1 | grep -i error
   ```

3. **Verify assertions work**
   ```bash
   # Run with assertion checking
   make run TEST=apb_smoke_test 2>&1 | grep "Error:.*assert"
   ```

## Best Practices

### 1. Development Workflow

```bash
# 1. Quick check during development
make regression

# 2. Final verification before commit
make verify

# 3. Check specific test
make run TEST=apb_smoke_test 2>&1 | tee output.log
grep -i error output.log
```

### 2. Assertion Development

When adding assertions:

1. **Add assertion to interface/design**
2. **Test assertion works**
   ```bash
   make run TEST=apb_smoke_test 2>&1 | grep "Error:.*assert"
   ```
3. **Fix any assertion errors**
4. **Run comprehensive verification**
   ```bash
   make verify
   ```

### 3. Regression Testing

For final verification:

```bash
# Always use comprehensive verification
make verify

# Check results
echo $?  # 0 = all pass, 1 = some fail
```

## Error Types Reference

### UVM Errors
```
UVM_ERROR: Error message
UVM_FATAL: Fatal message
```
- Captured by UVM report server
- Shown in UVM Report Summary
- Counted in `UVM_ERROR` and `UVM_FATAL`

### Assertion Errors
```
Error: "../src/file.sv", line: Assertion failed
```
- Reported by `$error` system task
- NOT captured by UVM
- Only in simulation output

### Simulation Errors
```
Error: Simulation error message
```
- General simulation errors
- NOT captured by UVM
- Only in simulation output

### License Errors
```
Failed to obtain license
```
- License server issues
- Environment variable problems
- Server not running

## Verification Checklist

Before committing code:

- [ ] All tests pass with `make verify`
- [ ] No UVM errors or fatals
- [ ] No assertion errors
- [ ] No simulation errors
- [ ] License working properly
- [ ] Compilation clean

## Troubleshooting

### Problem: False Pass

**Symptom:**
```bash
make regression  # Shows all pass
make verify      # Shows failures
```

**Solution:**
- Use `make verify` for final verification
- Check assertion errors in output
- Review assertion timing conditions

### Problem: Assertion Errors

**Symptom:**
```
Error: "../src/apb_interface.sv", 94: Assertion failed
```

**Solution:**
1. Check assertion timing
2. Verify signal behavior
3. Fix assertion or design
4. Re-run verification

### Problem: License Errors

**Symptom:**
```
Failed to obtain license
```

**Solution:**
```bash
# Check license server
ps aux | grep lmgrd

# Check environment variable
echo $SNPSLMD_LICENSE_FILE

# Set correct port
export SNPSLMD_LICENSE_FILE=27000@localhost
```

## Tools Reference

### Makefile Targets

| Target | Description |
|--------|-------------|
| `make comp` | Compile design |
| `make run` | Run single test |
| `make regression` | Basic regression (UVM errors only) |
| `make verify` | Comprehensive verification (all errors) |
| `make clean` | Clean build artifacts |

### Verification Script

```bash
# Run comprehensive verification
./verify_regression.sh

# Or via Makefile
make verify
```

## Conclusion

**Always use `make verify` for final verification** to ensure:
- No UVM errors
- No assertion errors
- No simulation errors
- All tests complete successfully

This prevents false passes and ensures design correctness.
