#!/bin/bash
# Comprehensive regression verification script
# Checks for ALL types of errors, not just UVM errors

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Comprehensive Regression Verification ==="
echo ""

# Check if SNPSLMD_LICENSE_FILE is set
if [ -z "$SNPSLMD_LICENSE_FILE" ]; then
    echo -e "${RED}ERROR: SNPSLMD_LICENSE_FILE not set${NC}"
    echo "Please set: export SNPSLMD_LICENSE_FILE=27000@localhost"
    exit 1
fi

# Test cases
TESTS=(
    "apb_smoke_test"
    "apb_directed_test"
    "apb_random_test"
    "apb_slverr_test"
    "apb_wait_state_test"
    "apb_reset_test"
)

PASSED=0
FAILED=0
TOTAL=${#TESTS[@]}

for test in "${TESTS[@]}"; do
    echo -n "Running $test... "

    # Run test and capture output
    OUTPUT=$(make run TEST=$test 2>&1)

    # Check for ALL types of errors
    ERROR_FOUND=0

    # Check for UVM errors
    if echo "$OUTPUT" | grep -q "UVM_ERROR"; then
        UVM_ERRORS=$(echo "$OUTPUT" | grep "UVM_ERROR" | grep -v "UVM_ERROR :    0" | head -5)
        if [ -n "$UVM_ERRORS" ]; then
            echo -e "${RED}UVM ERROR${NC}"
            echo "$UVM_ERRORS"
            ERROR_FOUND=1
        fi
    fi

    # Check for UVM fatals
    if echo "$OUTPUT" | grep -q "UVM_FATAL"; then
        UVM_FATALS=$(echo "$OUTPUT" | grep "UVM_FATAL" | grep -v "UVM_FATAL :    0" | head -5)
        if [ -n "$UVM_FATALS" ]; then
            echo -e "${RED}UVM FATAL${NC}"
            echo "$UVM_FATALS"
            ERROR_FOUND=1
        fi
    fi

    # Check for assertion errors (VCS specific)
    if echo "$OUTPUT" | grep -q "Error:.*assert"; then
        ASSERT_ERRORS=$(echo "$OUTPUT" | grep "Error:.*assert" | head -5)
        echo -e "${RED}ASSERTION ERROR${NC}"
        echo "$ASSERT_ERRORS"
        ERROR_FOUND=1
    fi

    # Check for general simulation errors
    if echo "$OUTPUT" | grep -q "^Error:"; then
        SIM_ERRORS=$(echo "$OUTPUT" | grep "^Error:" | head -5)
        echo -e "${RED}SIMULATION ERROR${NC}"
        echo "$SIM_ERRORS"
        ERROR_FOUND=1
    fi

    # Check for VCS errors
    if echo "$OUTPUT" | grep -q "Failed to obtain license"; then
        echo -e "${RED}LICENSE ERROR${NC}"
        ERROR_FOUND=1
    fi

    # Check for compilation errors
    if echo "$OUTPUT" | grep -q "compilation error"; then
        echo -e "${RED}COMPILATION ERROR${NC}"
        ERROR_FOUND=1
    fi

    # Check if test completed successfully
    if ! echo "$OUTPUT" | grep -q "\$finish called"; then
        echo -e "${RED}TEST DID NOT COMPLETE${NC}"
        ERROR_FOUND=1
    fi

    # Report result
    if [ $ERROR_FOUND -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "=== Regression Summary ==="
echo "Total: $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}✗ Some tests failed!${NC}"
    exit 1
fi
