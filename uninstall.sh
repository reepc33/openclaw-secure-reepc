#!/bin/bash
#
# OpenClaw Secure - Uninstall Script
# Safely removes security hardening without destroying user's OpenClaw
#

set -euo pipefail

# 日志函数
log_info() {
    echo "📁 $1"
}

log_warn() {
    echo "⚠️  $1" >&2
}

echo ""
echo "🗑️  OpenClaw Secure Uninstaller"
echo "================================"
echo ""
echo "⚠️  This will remove security hardening configurations"
echo "   but keep your OpenClaw installation intact"
echo ""

OC_DIR="$HOME/.openclaw"

# 兼容性读取函数
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

# 检查是否已安装
if [ ! -f "$OC_DIR/config.sha256" ]; then
    log_warn "OpenClaw Secure doesn't appear to be installed"
    echo "   Nothing to uninstall"
    exit 0
fi

# 确认卸载
local confirm
read_compat "Continue with uninstall? [y/N] " confirm "N"

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled"
    exit 0
fi

echo ""

# 询问是否恢复原始配置
if ls "$OC_DIR/backup"/openclaw.json.backup.* >/dev/null 2>&1; then
    LATEST_BACKUP=$(ls -t "$OC_DIR/backup"/openclaw.json.backup.* 2>/dev/null | head -1)
    if [ -n "$LATEST_BACKUP" ]; then
        echo "📂 Found backup config: $LATEST_BACKUP"
        local restore_config
        read_compat "Restore original configuration? [Y/n] " restore_config "Y"
        
        if [ "$restore_config" != "n" ] && [ "$restore_config" != "N" ]; then
            if cp "$LATEST_BACKUP" "$OC_DIR/openclaw.json"; then
                echo "✅ Original configuration restored"
            else
                log_warn "Failed to restore configuration"
            fi
        fi
    fi
else
    log_warn "No backup configuration found"
fi

echo ""

# 询问是否删除 AGENTS.md
if [ -f "$OC_DIR/workspace/AGENTS.md" ]; then
    local remove_agents
    read_compat "Remove security guidelines (AGENTS.md)? [y/N] " remove_agents "N"
    if [ "$remove_agents" = "y" ] || [ "$remove_agents" = "Y" ]; then
        if rm -f "$OC_DIR/workspace/AGENTS.md"; then
            echo "✅ AGENTS.md removed"
        else
            log_warn "Failed to remove AGENTS.md"
        fi
    fi
fi

# 询问是否删除审计脚本
if [ -d "$OC_DIR/workspace/scripts" ]; then
    local remove_scripts
    read_compat "Remove security audit scripts? [y/N] " remove_scripts "N"
    if [ "$remove_scripts" = "y" ] || [ "$remove_scripts" = "Y" ]; then
        if rm -rf "$OC_DIR/workspace/scripts"; then
            echo "✅ Audit scripts removed"
        else
            log_warn "Failed to remove audit scripts"
        fi
    fi
fi

# 询问是否删除定时任务
echo ""
local remove_cron
read_compat "Remove daily security audit cron job? [Y/n] " remove_cron "Y"
if [ "$remove_cron" != "n" ] && [ "$remove_cron" != "N" ]; then
    if crontab -l 2>/dev/null | grep -q "security-audit.sh"; then
        if crontab -l 2>/dev/null | grep -v "security-audit.sh" | crontab - 2>/dev/null; then
            echo "✅ Cron job removed"
            
            # 尝试重启 cron 服务（Linux）
            if [ "$(uname -s)" = "Linux" ]; then
                # 尝试多种方式重启 cron
                if command -v systemctl >/dev/null 2>&1; then
                    if systemctl is-active --quiet cron 2>/dev/null || systemctl is-active --quiet crond 2>/dev/null; then
                        log_info "Attempting to reload cron service..."
                        sudo systemctl reload cron 2>/dev/null || \
                        sudo systemctl reload crond 2>/dev/null || \
                        log_warn "Could not reload cron service (may require manual restart)"
                    fi
                elif command -v service >/dev/null 2>&1; then
                    log_info "Attempting to reload cron service..."
                    sudo service cron reload 2>/dev/null || \
                    sudo service crond reload 2>/dev/null || \
                    log_warn "Could not reload cron service"
                fi
            fi
        else
            log_warn "Failed to remove cron job"
        fi
    else
        log_info "No cron job found"
    fi
fi

# 询问是否删除 hash baseline
echo ""
local remove_baseline
read_compat "Remove config hash baseline? [y/N] " remove_baseline "N"
if [ "$remove_baseline" = "y" ] || [ "$remove_baseline" = "Y" ]; then
    if rm -f "$OC_DIR/config.sha256" "$OC_DIR/agents.md.sha256" 2>/dev/null; then
        echo "✅ Hash baseline removed"
    else
        log_warn "Failed to remove hash baseline"
    fi
fi

# 询问是否删除 token 文件
if [ -f "$OC_DIR/.auth_token" ]; then
    local remove_token
    read_compat "Remove auth token file? [y/N] " remove_token "N"
    if [ "$remove_token" = "y" ] || [ "$remove_token" = "Y" ]; then
        if rm -f "$OC_DIR/.auth_token"; then
            echo "✅ Auth token file removed"
        else
            log_warn "Failed to remove auth token file"
        fi
    fi
fi

echo ""
echo "================================"
echo "🎉 Uninstall Complete"
echo "================================"
echo ""
echo "📌 OpenClaw has been restored to pre-hardening state"
echo "🔄 Please restart OpenClaw: openclaw restart"
echo ""
