#!/bin/bash
#
# OpenClaw Secure - Security Audit Script
# Performs 10 security checks
#

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

# Initialize report
cat > "$REPORT_FILE" <<EOF
🛡️ OpenClaw Security Audit Report
================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Host: $(hostname)
User: $(whoami)
================================

EOF

# 1. Configuration baseline check
echo "[1/10] Checking configuration baseline..."
if [ -f "$OC_DIR/config.sha256" ]; then
    if sha256sum -c "$OC_DIR/config.sha256" --status 2>/dev/null; then
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
    PERM=$(stat -c "%a" "$CONFIG" 2>/dev/null || stat -f "%Lp" "$CONFIG" 2>/dev/null)
    if [ "$PERM" = "600" ]; then
        check_pass "Config file permissions secure (600)"
    else
        check_fail "Config file permissions insecure ($PERM)"
    fi
else
    check_fail "Configuration file not found"
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
        check_warn "OpenClaw listener not detected"
    fi
else
    check_warn "Cannot check ports (ss not available)"
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
else
    check_fail "Cannot read configuration"
fi

# 5. Sensitive file scan
echo "[5/10] Scanning for sensitive files..."
SENSITIVE=$(find "$OC_DIR/workspace" -type f \( -name "*.key" -o -name "*.pem" -o -name ".env" -o -name "id_rsa" \) 2>/dev/null | head -10)
if [ -n "$SENSITIVE" ]; then
    check_warn "Potentially sensitive files found:"
    echo "$SENSITIVE" | sed 's/^/     /' | tee -a "$REPORT_FILE"
else
    check_pass "No obvious sensitive files found"
fi

# 6. Plaintext credential scan
echo "[6/10] Scanning for plaintext credentials..."
if grep -r "private.*key\|password.*=\|token.*=" "$OC_DIR/workspace/" 2>/dev/null | grep -v ".git" | head -5 | tee -a "$REPORT_FILE"; then
    check_warn "Potential plaintext credentials found (see above)"
else
    check_pass "No obvious plaintext credentials found"
fi

# 7. AGENTS.md check
echo "[7/10] Checking security guidelines..."
if [ -f "$OC_DIR/workspace/AGENTS.md" ]; then
    check_pass "AGENTS.md security guidelines present"
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
    SKILL_COUNT=$(clawhub list 2>/dev/null | wc -l)
    if [ "$SKILL_COUNT" -eq 0 ]; then
        check_pass "No third-party skills installed (safest)"
    else
        check_warn "$SKILL_COUNT skills installed, please review regularly"
    fi
else
    check_warn "Cannot check skills (clawhub not available)"
fi

# 10. Disk space check
echo "[10/10] Checking disk space..."
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$DISK_USAGE" -lt 85 ]; then
    check_pass "Disk usage normal ($DISK_USAGE%)"
else
    check_fail "Disk usage high ($DISK_USAGE%)"
fi

# Generate summary
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

# Append summary to full report
cat "$SUMMARY_FILE" >> "$REPORT_FILE"

echo ""
echo "===================="
echo "Audit Complete"
echo "===================="

exit $FAIL
