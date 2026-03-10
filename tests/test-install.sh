#!/bin/bash
#
# Test installation script functionality
# Note: This is a dry-run test, doesn't actually install
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Testing install.sh..."

# 测试 1: 检查脚本是否存在且可执行
if [ ! -f "$PROJECT_DIR/install.sh" ]; then
    echo "FAIL: install.sh not found"
    exit 1
fi

# 测试 2: 语法检查
if ! bash -n "$PROJECT_DIR/install.sh"; then
    echo "FAIL: Syntax errors in install.sh"
    exit 1
fi

# 测试 3: 检查关键函数是否存在
if ! grep -q "check_system()" "$PROJECT_DIR/install.sh"; then
    echo "FAIL: check_system function not found"
    exit 1
fi

if ! grep -q "check_dependencies()" "$PROJECT_DIR/install.sh"; then
    echo "FAIL: check_dependencies function not found"
    exit 1
fi

if ! grep -q "read_compat()" "$PROJECT_DIR/install.sh"; then
    echo "FAIL: read_compat function not found"
    exit 1
fi

# 测试 4: 检查 shebang 和 set 选项
if ! head -1 "$PROJECT_DIR/install.sh" | grep -q "#!/bin/bash"; then
    echo "FAIL: Missing or incorrect shebang"
    exit 1
fi

if ! grep -q "set -euo pipefail" "$PROJECT_DIR/install.sh"; then
    echo "FAIL: Missing 'set -euo pipefail'"
    exit 1
fi

# 测试 5: 检查关键变量定义
if ! grep -q 'VERSION="v1.0.0"' "$PROJECT_DIR/install.sh"; then
    echo "FAIL: VERSION variable not defined"
    exit 1
fi

echo "All install.sh tests passed!"
exit 0
