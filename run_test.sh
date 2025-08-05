#!/bin/bash

# Exit immediately if any command fails
set -e

# --- Global Configuration ---
# Set up OpenMPI environment
export OMPI_PRTERUN=/usr/lib64/openmpi/bin/prterun
MPIRUN="/usr/lib64/openmpi/bin/mpirun"
EXEC="./random_walk"

# Test tracking variables
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to run a single test case
run_test() {
    local test_name="$1"
    local np="$2"
    local domain_size="$3"
    local max_steps="$4"
    local expected_walkers=$((np - 1))
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "${BLUE}=== Test $TOTAL_TESTS: $test_name ===${NC}"
    echo "Command: $MPIRUN -np $np $EXEC $domain_size $max_steps"
    
    # Run the test and capture output
    if OUTPUT=$($MPIRUN --oversubscribe -np $np $EXEC $domain_size $max_steps 2>&1); then
        # Count "finished" messages
        FINISHED_COUNT=$(echo "$OUTPUT" | grep -c "finished" || echo "0")
        
        # Check if controller message exists
        CONTROLLER_MSG=$(echo "$OUTPUT" | grep "Controller: All $expected_walkers walkers have finished." || echo "")
        
        # Validate walker message format
        WALKER_FORMAT_OK=true
        while IFS= read -r line; do
            if [[ $line == *"Walker finished"* ]]; then
                if ! [[ $line =~ ^Rank\ [0-9]+:\ Walker\ finished\ in\ [0-9]+\ steps\.$ ]]; then
                    WALKER_FORMAT_OK=false
                    break
                fi
            fi
        done <<< "$OUTPUT"
        
        # Check test results
        if [ "$FINISHED_COUNT" -eq "$((expected_walkers + 1))" ] && [ -n "$CONTROLLER_MSG" ] && [ "$WALKER_FORMAT_OK" = true ]; then
            echo -e "${GREEN}✅ Test Passed${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ Test Failed${NC}"
            echo "Expected: $((expected_walkers + 1)) 'finished' messages, Found: $FINISHED_COUNT"
            echo "Controller message found: $([ -n "$CONTROLLER_MSG" ] && echo "Yes" || echo "No")"
            echo "Walker format correct: $WALKER_FORMAT_OK"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${RED}❌ Test Failed - Program crashed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    echo "--- Program Output ---"
    echo "$OUTPUT"
    echo
}

echo -e "${YELLOW}🧪 Running Comprehensive MPI Random Walk Tests${NC}"
echo "=================================================="
echo

# Test Case 1: Basic functionality (README sample)
run_test "Basic functionality (README sample)" 5 20 10000

# Test Case 2: Minimum configuration
run_test "Minimum configuration (2 processes)" 2 10 1000

# Test Case 3: Small domain (quick boundary exits)
run_test "Small domain boundary test" 4 2 10000

# Test Case 4: Max steps limit test
run_test "Max steps limit test" 3 100 5

# Test Case 5: Large number of processes
run_test "Large number of processes" 8 15 5000

# Test Case 6: Edge case - Domain size 1
run_test "Minimal domain size" 3 1 1000

# Test Case 7: Medium configuration
run_test "Medium configuration" 6 30 2000

# Summary
echo "=================================================="
echo -e "${YELLOW}📊 Test Summary${NC}"
echo "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
