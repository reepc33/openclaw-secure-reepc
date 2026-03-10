#!/bin/bash
#
# OpenClaw Secure - Entry Installation Script
# Version: v1.0.0
# Repository: https://github.com/reepc33/openclaw-secure
#

set -euo pipefail

VERSION="v1.0.0"
REPO="reepc33/openclaw-secure"
MIN_OPENCLAW_VERSION="0.9.0"

# 日志函数
log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1" >&2
}

log_error() {
    echo "[ERROR] $1" >&2
}

# 兼容性读取函数（替代 read -p）
read_compat() {
    local prompt="$1"
    local var_name="$2"
    local default_value="${3:-}"
    
    printf "%s" "$prompt"
    read -r "$var_name"
    
    if [ -z "${!var_name}" ] && [ -n "$default_value" ]; then
        eval "$var_name='$default_value'"
    fi
}

# 系统检测函数
check_system() {
    log_info "Checking system compatibility..."
    
    case "$(uname -s)" in
        Linux*)
            OS="linux"
            ;;
        Darwin*)
            OS="macos"
            log_warn "macOS detected. Some features (firewall, cron) may not work as expected."
            ;;
        CYGWIN*|MINGW*|MSYS*)
            log_error "Windows detected. Please use WSL (Windows Subsystem for Linux)."
            exit 1
            ;;
        *)
            log_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac
    
    log_info "Operating system: $OS"
}

# 检查依赖项
check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    local optional_missing=()
    
    # 必需依赖
    local required_deps=("bash" "openssl" "curl" "sha256sum")
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    # 可选依赖
    local optional_deps=("ss" "ufw" "crontab")
    for dep in "${optional_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            optional_missing+=("$dep")
        fi
    done
    
    # 检查 Node.js
    if ! command -v node >/dev/null 2>&1; then
        log_error "Node.js is not installed"
        log_info "Please install Node.js 16+ first: https://nodejs.org/"
        exit 1
    fi
    
    # 检查 Node.js 版本
    NODE_VERSION=$(node --version | sed 's/v//')
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    if [ "$NODE_MAJOR" -lt 16 ]; then
        log_error "Node.js version $NODE_VERSION is too old. Requires 16+."
        exit 1
    fi
    log_info "Node.js version: $NODE_VERSION"
    
    # 检查 npm
    if ! command -v npm >/dev/null 2>&1; then
        log_error "npm is not installed"
        exit 1
    fi
    
    # 检查 OpenClaw
    if ! command -v openclaw >/dev/null 2>&1; then
        log_error "OpenClaw not detected"
        echo ""
        echo "Please install OpenClaw first:"
        echo "   npm install -g @openclaw/cli"
        echo ""
        exit 1
    fi
    
    # 检查 OpenClaw 版本
    OPENCLAW_VERSION=$(openclaw --version 2>/dev/null || echo "unknown")
    log_info "OpenClaw version: $OPENCLAW_VERSION"
    
    # 报告缺失的必需依赖
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install them first:"
        log_info "  Ubuntu/Debian: sudo apt-get install ${missing_deps[*]}"
        log_info "  macOS: brew install ${missing_deps[*]}"
        exit 1
    fi
    
    # 报告可选依赖
    if [ ${#optional_missing[@]} -ne 0 ]; then
        log_warn "Optional dependencies missing: ${optional_missing[*]}"
        log_info "Some features may be limited."
    fi
    
    log_info "All required dependencies found"
}

# 检查更新
check_updates() {
    log_info "Checking for updates..."
    
    local latest
    if ! latest=$(curl -s --max-time 10 "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'); then
        log_warn "Failed to check for updates (network timeout or error)"
        return 0
    fi
    
    if [ -n "$latest" ] && [ "$latest" != "$VERSION" ]; then
        echo ""
        log_warn "New version available: $latest (current: $VERSION)"
        log_info "Download: https://github.com/$REPO/releases"
        echo ""
        
        local continue_old
        read_compat "Continue with current version? [Y/n] " continue_old "Y"
        
        if [ "$continue_old" = "n" ] || [ "$continue_old" = "N" ]; then
            log_info "Cancelled. Please download the new version."
            exit 0
        fi
    else
        log_info "Already up to date"
    fi
}

# 配置防火墙
configure_firewall() {
    log_info "Checking firewall configuration..."
    
    local configure_fw
    read_compat "Configure firewall to block external access to port 18789? [Y/n] " configure_fw "Y"
    
    if [ "$configure_fw" = "n" ] || [ "$configure_fw" = "N" ]; then
        log_info "Skipping firewall configuration"
        return 0
    fi
    
    # 检测并配置防火墙
    if command -v ufw >/dev/null 2>&1; then
        log_info "Configuring UFW firewall..."
        
        # 检查 UFW 状态
        if ! sudo ufw status | grep -q "Status: active"; then
            log_warn "UFW is not active. Skipping firewall configuration."
            log_info "To enable UFW, run: sudo ufw enable"
            return 0
        fi
        
        # 添加规则：只允许本地访问 18789
        sudo ufw deny 18789 >/dev/null 2>&1 || true
        sudo ufw allow from 127.0.0.1 to any port 18789 >/dev/null 2>&1 || true
        
        log_info "UFW rules configured"
        
    elif command -v iptables >/dev/null 2>&1; then
        log_info "Configuring iptables..."
        
        # 添加规则
        sudo iptables -A INPUT -p tcp --dport 18789 -s 127.0.0.1 -j ACCEPT 2>/dev/null || true
        sudo iptables -A INPUT -p tcp --dport 18789 -j DROP 2>/dev/null || true
        
        log_info "iptables rules configured (temporary, will not persist after reboot)"
        log_warn "To make rules persistent, install iptables-persistent"
        
    else
        log_warn "No supported firewall (UFW/iptables) found"
        log_info "Please manually configure firewall to block port 18789 from external access"
    fi
}

# 主函数
main() {
    echo ""
    echo "🛡️  OpenClaw Secure Installer"
    echo "================================"
    echo "Version: $VERSION"
    echo ""
    
    # 检查是否以 root 运行
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        log_error "Do not run this script as root"
        log_info "Please switch to a regular user and try again"
        exit 1
    fi
    
    # 系统检测
    check_system
    
    # 检查依赖
    check_dependencies
    
    # 检查更新
    check_updates
    
    # 显示将要执行的操作
    echo ""
    echo "⚠️  This script will perform the following operations:"
    echo "   1. Backup existing config to ~/.openclaw/backup/"
    echo "   2. Create secure openclaw.json (disable dangerous features)"
    echo "   3. Create AGENTS.md security guidelines"
    echo "   4. Set file permissions to 600/700"
    echo "   5. Generate config hash baseline"
    echo "   6. Create security audit script"
    echo "   7. Optional: Configure firewall"
    echo "   8. Optional: Add daily automatic security audit"
    echo ""
    
    local confirm
    read_compat "Continue installation? [Y/n] " confirm "Y"
    
    if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    # 执行核心安装
    echo ""
    log_info "Starting installation..."
    echo ""
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if ! bash "$SCRIPT_DIR/secure-init.sh"; then
        log_error "Core installation failed"
        exit 1
    fi
    
    # 配置防火墙
    configure_firewall
    
    # 询问是否添加定时任务
    echo ""
    local add_cron
    read_compat "Add daily automatic security audit (3 AM)? [Y/n] " add_cron "Y"
    
    if [ "$add_cron" != "n" ] && [ "$add_cron" != "N" ]; then
        CRON_CMD="0 3 * * * /bin/bash $HOME/.openclaw/workspace/scripts/security-audit.sh >> /tmp/openclaw-cron.log 2>&1"
        
        # 检查是否已存在
        if crontab -l 2>/dev/null | grep -q "security-audit.sh"; then
            log_info "Cron job already exists, skipping"
        else
            (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
            log_info "Daily audit cron job added"
        fi
    fi
    
    # 完成信息
    echo ""
    echo "================================"
    echo "🎉 Installation Complete!"
    echo "================================"
    echo ""
    echo "📋 Next steps:"
    echo ""
    echo "1️⃣  View security audit report:"
    echo "   cat /tmp/openclaw-security-reports/latest-summary.txt"
    echo ""
    echo "2️⃣  Run security audit manually:"
    echo "   ~/.openclaw/workspace/scripts/security-audit.sh"
    echo ""
    echo "3️⃣  Edit security guidelines (optional):"
    echo "   nano ~/.openclaw/workspace/AGENTS.md"
    echo ""
    echo "4️⃣  View configuration:"
    echo "   cat ~/.openclaw/openclaw.json"
    echo ""
    echo "📖 Full documentation: https://github.com/$REPO/blob/main/README.md"
    echo "🗑️  Uninstall: bash uninstall.sh"
    echo ""
    echo "⚠️  Important reminders:"
    echo "   • Auth Token is saved in ~/.openclaw/openclaw.json"
    echo "   • Do not share this file with others"
    echo "   • Run audit script regularly to check security status"
    echo "   • Review firewall rules: sudo ufw status"
    echo ""
}

# 运行主函数
main "$@"
