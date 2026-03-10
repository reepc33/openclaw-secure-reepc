#!/bin/bash
#
# Test audit script functionality
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Testing security-audit.sh..."

# 测试 1: 检查脚本是否存在
if [ ! -f "$PROJECT_DIR/scripts/security-audit.sh" ]; then
    echo "FAIL: security-audit.sh not found"
    exit 1
fi

# 测试 2: 语法检查
if ! bash -n "$PROJECT_DIR/scripts/security-audit.sh"; then
    echo "FAIL: Syntax errors in security-audit.sh"
    exit 1
fi

# 测试 3: 检查关键函数
if ! grep -q "get_file_perms()" "$PROJECT_DIR/scripts/security-audit.sh"; then
    echo "FAIL: get_file_perms function not found"
    exit 1
fi

if ! grep -q "check_pass()" "$PROJECT_DIR/scripts/security-audit.sh"; then
    echo "FAIL: check_pass function not found"
    exit 1
fi

# 测试 4: 检查跨平台兼容性
if ! grep -q "uname -s" "$PROJECT_DIR/scripts/security-audit.sh"; then
    echo "WARN: OS detection not found (may affect portability)"
fi

# 测试 5: 检查报告目录创建
if ! grep -q "REPORT_DIR" "$PROJECT_DIR/scripts/security-audit.sh"; then
    echo "FAIL: REPORT_DIR not defined"
    exit 1
fi

echo "All audit script tests passed!"
exit 0
