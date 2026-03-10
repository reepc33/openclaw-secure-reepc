#!/bin/bash
#
# Test Suite for OpenClaw Secure
# Run all tests
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🧪 OpenClaw Secure Test Suite"
echo "=============================="
echo ""

FAILED=0
PASSED=0

# 运行单个测试
run_test() {
    local test_name="$1"
    local test_script="$2"
    
    echo "Running: $test_name"
    if bash "$test_script" 2>&1; then
        echo "  ✅ PASSED"
        ((PASSED++))
    else
        echo "  ❌ FAILED"
        ((FAILED++))
    fi
    echo ""
}

# 检查脚本语法
check_syntax() {
    local script="$1"
    local name="$2"
    
    echo "Checking syntax: $name"
    if bash -n "$script" 2>&1; then
        echo "  ✅ Syntax OK"
        ((PASSED++))
    else
        echo "  ❌ Syntax Error"
        ((FAILED++))
    fi
}

echo "📋 Phase 1: Syntax Checks"
echo "-------------------------"
check_syntax "$PROJECT_DIR/install.sh" "install.sh"
check_syntax "$PROJECT_DIR/secure-init.sh" "secure-init.sh"
check_syntax "$PROJECT_DIR/uninstall.sh" "uninstall.sh"
check_syntax "$PROJECT_DIR/scripts/security-audit.sh" "security-audit.sh"
echo ""

echo "📋 Phase 2: Script Tests"
echo "------------------------"
# 如果存在特定测试脚本，运行它们
if [ -f "$SCRIPT_DIR/test-install.sh" ]; then
    run_test "Installation Test" "$SCRIPT_DIR/test-install.sh"
fi

if [ -f "$SCRIPT_DIR/test-audit.sh" ]; then
    run_test "Audit Script Test" "$SCRIPT_DIR/test-audit.sh"
fi

if [ -f "$SCRIPT_DIR/test-functions.sh" ]; then
    run_test "Function Tests" "$SCRIPT_DIR/test-functions.sh"
fi

echo "📋 Phase 3: Configuration Validation"
echo "-------------------------------------"
# 检查 JSON 模板
if command -v jq >/dev/null 2>&1; then
    echo "Validating JSON templates..."
    if jq empty "$PROJECT_DIR/templates/openclaw.json" 2>&1; then
        echo "  ✅ openclaw.json valid"
        ((PASSED++))
    else
        echo "  ❌ openclaw.json invalid"
        ((FAILED++))
    fi
else
    echo "⚠️  jq not available, skipping JSON validation"
fi
echo ""

echo "=============================="
echo "Test Results"
echo "=============================="
echo "✅ Passed: $PASSED"
echo "❌ Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "🎉 All tests passed!"
    exit 0
else
    echo "⚠️  Some tests failed"
    exit 1
fi
