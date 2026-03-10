#!/bin/bash
#
# OpenClaw Secure - Security Audit Script
# Performs 10 security checks
#

set -euo pipefail

OC_DIR="$HOME/.openclaw"
CONFIG="$OC_DIR/openclaw.json"
REPORT_DIR="/tmp/openclaw-security-reports"
DATE=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="$REPORT_DIR/report-$DATE.txt"
SUMMARY_FILE="$REPORT_DIR/latest-summary.txt"

mkdir -p "$REPORT_DIR"

echo "🛡️  OpenClaw Security Audit"
echo "===================="
echo ""

PASS=0
FAIL=0
WARN=0

# 兼容性检查函数
check_pass() {
    echo "✅ $1" | tee -a "$REPORT_FILE"
    ((PASS++))
}

check_fail() {
    echo "❌ $1" | tee -a "$REPORT_FILE"
    ((FAIL++))
}

check_warn() {
    echo "⚠️  $1" | tee -a "$REPORT_FILE"
    ((WARN++))
}

# 跨平台获取文件权限
get_file_perms() {
    local file="$1"
    local perms=""
    
    # 尝试 Linux 风格的 stat
    if perms=$(stat -c "%a" "$file" 2>/dev/null); then
        echo "$perms"
        return 0
    fi
    
    # 尝试 macOS/BSD 风格的 stat
    if perms=$(stat -f "%Lp" "$file" 2>/dev/null); then
        echo "$perms"
        return 0
    fi
    
    # 备选方案：使用 ls
    if command -v ls >/dev/null 2>&1; then
        perms=$(ls -l "$file" 2>/dev/null | awk '{print $1}' | sed 's/[^rwx-]//g')
        # 转换为数字
        local num_perms=0
        [ "${perms:0:1}" = "r" ] && ((num_perms+=400))
        [ "${perms:1:1}" = "w" ] && ((num_perms+=200))
        [ "${perms:2:1}" = "x" ] && ((num_perms+=100))
        [ "${perms:3:1}" = "r" ] && ((num_perms+=40))
        [ "${perms:4:1}" = "w" ] && ((num_perms+=20))
        [ "${perms:5:1}" = "x" ] && ((num_perms+=10))
        [ "${perms:6:1}" = "r" ] && ((num_perms+=4))
        [ "${perms:7:1}" = "w" ] && ((num_perms+=2))
        [ "${perms:8:1}" = "x" ] && ((num_perms+=1))
        echo "$num_perms"
        return 0
    fi
    
    echo "unknown"
    return 1
}

# 初始化报告
cat > "$REPORT_FILE" <<EOF
🛡️ OpenClaw Security Audit Report
================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Host: $(hostname)
User: $(whoami)
OS: $(uname -s)
================================

EOF

# 1. Configuration baseline check
echo "[1/10] Checking configuration baseline..."
if [ -f "$OC_DIR/config.sha256" ]; then
    if sha256sum -c "$OC_DIR/config.sha256" --status 2>/dev/null || \
       sha256sum -c "$OC_DIR/config.sha256" 2>/dev/null | grep -q "OK"; then
        check_pass "Configuration not modified"
    else
        check_fail "Configuration may have been tampered with"
    fi
else
    check_warn "No config baseline found"
fi

# 2. Permission check
echo "[2/10] Checking file permissions..."
if [ -f "$CONFIG" ]; then
    PERM=$(get_file_perms "$CONFIG")
    if [ "$PERM" = "600" ]; then
        check_pass "Config file permissions secure (600)"
    elif [ "$PERM" = "unknown" ]; then
        check_warn "Cannot determine file permissions"
    else
        check_fail "Config file permissions insecure ($PERM)"
    fi
else
    check_fail "Configuration file not found"
fi

# 检查 .auth_token 文件权限
if [ -f "$OC_DIR/.auth_token" ]; then
    TOKEN_PERM=$(get_file_perms "$OC_DIR/.auth_token")
    if [ "$TOKEN_PERM" = "600" ]; then
        check_pass "Token file permissions secure (600)"
    else
        check_warn "Token file permissions may be insecure ($TOKEN_PERM)"
    fi
fi

# 3. Network listener check
echo "[3/10] Checking network listeners..."
if command -v ss >/dev/null 2>&1; then
    PORT_INFO=$(ss -tln 2>/dev/null | grep 18789 || true)
    if echo "$PORT_INFO" | grep -q "127.0.0.1"; then
        check_pass "Listening only on localhost"
    elif echo "$PORT_INFO" | grep -q "0.0.0.0"; then
        check_fail "WARNING: Exposed to public network (0.0.0.0)"
    else
        check_warn "OpenClaw listener not detected (may not be running)"
    fi
elif command -v netstat >/dev/null 2>&1; then
    # macOS 可能只有 netstat
    PORT_INFO=$(netstat -tln 2>/dev/null | grep 18789 || true)
    if echo "$PORT_INFO" | grep -q "127.0.0.1"; then
        check_pass "Listening only on localhost"
    elif echo "$PORT_INFO" | grep -q "0.0.0.0"; then
        check_fail "WARNING: Exposed to public network (0.0.0.0)"
    else
        check_warn "OpenClaw listener not detected"
    fi
else
    check_warn "Cannot check ports (ss/netstat not available)"
fi

# 4. Security configuration check
echo "[4/10] Checking security configuration..."
if [ -f "$CONFIG" ]; then
    if grep -q '"host": "127.0.0.1"' "$CONFIG"; then
        check_pass "Gateway bound to localhost only"
    else
        check_fail "Gateway may be bound to public address"
    fi
    
    if grep -q '"auth":' "$CONFIG" && grep -q '"enabled": true' "$CONFIG"; then
        check_pass "Authentication enabled"
    else
        check_fail "Authentication not enabled"
    fi
    
    if grep -q '"file_delete": false' "$CONFIG"; then
        check_pass "File delete function disabled"
    else
        check_warn "File delete function enabled"
    fi
    
    if grep -q '"shell_execute": false' "$CONFIG"; then
        check_pass "Shell execute function disabled"
    else
        check_warn "Shell execute function enabled"
    fi
    
    # 检查 token 存储方式
    if grep -q '"tokenSource": "file"' "$CONFIG"; then
        check_pass "Token source configuration present"
    fi
else
    check_fail "Cannot read configuration"
fi

# 5. Sensitive file scan
echo "[5/10] Scanning for sensitive files..."
if [ -d "$OC_DIR/workspace" ]; then
    SENSITIVE=$(find "$OC_DIR/workspace" -type f \( -name "*.key" -o -name "*.pem" -o -name ".env" -o -name "id_rsa" -o -name "*.p12" -o -name "*.pfx" \) 2>/dev/null | head -10)
    if [ -n "$SENSITIVE" ]; then
        check_warn "Potentially sensitive files found:"
        echo "$SENSITIVE" | sed 's/^/     /' | tee -a "$REPORT_FILE"
    else
        check_pass "No obvious sensitive files found"
    fi
else
    check_warn "Workspace directory not found"
fi

# 6. Plaintext credential scan
echo "[6/10] Scanning for plaintext credentials..."
if [ -d "$OC_DIR/workspace/" ]; then
    # 搜索常见敏感模式，但排除 .git 和日志文件
    SENSITIVE_PATTERNS="private.*key|password.*=|token.*=|api_key|secret.*=|aws_access_key"
    FOUND_CREDS=$(grep -r -E "$SENSITIVE_PATTERNS" "$OC_DIR/workspace/" 2>/dev/null | grep -v ".git" | grep -v "audit.log" | grep -v ".backup." | head -5 || true)
    
    if [ -n "$FOUND_CREDS" ]; then
        check_warn "Potential plaintext credentials found (see above)"
        echo "$FOUND_CREDS" | tee -a "$REPORT_FILE"
    else
        check_pass "No obvious plaintext credentials found"
    fi
else
    check_warn "Workspace directory not accessible"
fi

# 7. AGENTS.md check
echo "[7/10] Checking security guidelines..."
if [ -f "$OC_DIR/workspace/AGENTS.md" ]; then
    check_pass "AGENTS.md security guidelines present"
    
    # 额外检查 AGENTS.md 是否被修改
    if [ -f "$OC_DIR/agents.md.sha256" ]; then
        if sha256sum -c "$OC_DIR/agents.md.sha256" --status 2>/dev/null || \
           sha256sum -c "$OC_DIR/agents.md.sha256" 2>/dev/null | grep -q "OK"; then
            check_pass "AGENTS.md not modified"
        else
            check_warn "AGENTS.md may have been modified"
        fi
    fi
else
    check_warn "AGENTS.md security guidelines not found"
fi

# 8. Audit log check
echo "[8/10] Checking audit logs..."
if [ -f "$OC_DIR/logs/audit.log" ]; then
    RECENT=$(tail -50 "$OC_DIR/logs/audit.log" 2>/dev/null | wc -l)
    check_pass "Audit log exists with $RECENT recent entries"
else
    check_warn "Audit log not found"
fi

# 9. Skill security check
echo "[9/10] Checking installed skills..."
if command -v clawhub >/dev/null 2>&1; then
    SKILL_COUNT=$(clawhub list 2>/dev/null | wc -l || echo "0")
    if [ "$SKILL_COUNT" -eq 0 ] 2>/dev/null; then
        check_pass "No third-party skills installed (safest)"
    else
        check_warn "$SKILL_COUNT skills installed, please review regularly"
    fi
else
    check_warn "Cannot check skills (clawhub not available)"
fi

# 10. Disk space check
echo "[10/10] Checking disk space..."
if command -v df >/dev/null 2>&1; then
    DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | tr -d '%' || echo "0")
    if [ "$DISK_USAGE" -lt 85 ] 2>/dev/null; then
        check_pass "Disk usage normal ($DISK_USAGE%)"
    else
        check_fail "Disk usage high ($DISK_USAGE%)"
    fi
else
    check_warn "Cannot check disk space (df not available)"
fi

# 生成摘要
cat > "$SUMMARY_FILE" <<EOF
🛡️ OpenClaw Security Audit Summary
================================
Date: $(date '+%Y-%m-%d %H:%M:%S')

✅ Passed: $PASS
❌ Failed: $FAIL
⚠️  Warnings: $WARN

EOF

if [ $FAIL -eq 0 ]; then
    echo "🎉 All critical checks passed" | tee -a "$SUMMARY_FILE"
else
    echo "⚠️  $FAIL critical issues found, please review report" | tee -a "$SUMMARY_FILE"
fi

echo "" | tee -a "$SUMMARY_FILE"
echo "📄 Full report: $REPORT_FILE" | tee -a "$SUMMARY_FILE"

# 将摘要追加到完整报告
cat "$SUMMARY_FILE" >> "$REPORT_FILE"

echo ""
echo "===================="
echo "Audit Complete"
echo "===================="

exit $FAIL
