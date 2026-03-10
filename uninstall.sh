#!/bin/bash
#
# OpenClaw Secure - Uninstall Script
# Safely removes security hardening without destroying user's OpenClaw
#

set -e

echo ""
echo "🗑️  OpenClaw Secure Uninstaller"
echo "================================"
echo ""
echo "⚠️  This will remove security hardening configurations"
echo "   but keep your OpenClaw installation intact"
echo ""

OC_DIR="$HOME/.openclaw"

# Check if OpenClaw Secure was installed
if [ ! -f "$OC_DIR/config.sha256" ]; then
    echo "ℹ️  OpenClaw Secure doesn't appear to be installed"
    echo "   Nothing to uninstall"
    exit 0
fi

read -p "Continue with uninstall? [y/N] " confirm

if [[ "$confirm" != "y" ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""

# Ask about restoring original config
if ls "$OC_DIR/backup"/openclaw.json.backup.* 1>/dev/null 2>&1; then
    LATEST_BACKUP=$(ls -t "$OC_DIR/backup"/openclaw.json.backup.* | head -1)
    echo "📂 Found backup config: $LATEST_BACKUP"
    read -p "Restore original configuration? [Y/n] " restore_config
    
    if [[ "$restore_config" != "n" ]]; then
        cp "$LATEST_BACKUP" "$OC_DIR/openclaw.json"
        echo "✅ Original configuration restored"
    fi
else
    echo "⚠️  No backup configuration found"
fi

echo ""

# Ask about removing AGENTS.md
if [ -f "$OC_DIR/workspace/AGENTS.md" ]; then
    read -p "Remove security guidelines (AGENTS.md)? [y/N] " remove_agents
    if [[ "$remove_agents" == "y" ]]; then
        rm -f "$OC_DIR/workspace/AGENTS.md"
        echo "✅ AGENTS.md removed"
    fi
fi

# Ask about removing audit scripts
if [ -d "$OC_DIR/workspace/scripts" ]; then
    read -p "Remove security audit scripts? [y/N] " remove_scripts
    if [[ "$remove_scripts" == "y" ]]; then
        rm -rf "$OC_DIR/workspace/scripts"
        echo "✅ Audit scripts removed"
    fi
fi

# Ask about removing cron job
echo ""
read -p "Remove daily security audit cron job? [Y/n] " remove_cron
if [[ "$remove_cron" != "n" ]]; then
    crontab -l 2>/dev/null | grep -v "security-audit.sh" | crontab - 2>/dev/null || true
    echo "✅ Cron job removed"
fi

# Ask about removing hash baseline
echo ""
read -p "Remove config hash baseline? [y/N] " remove_baseline
if [[ "$remove_baseline" == "y" ]]; then
    rm -f "$OC_DIR/config.sha256"
    echo "✅ Hash baseline removed"
fi

echo ""
echo "================================"
echo "🎉 Uninstall Complete"
echo "================================"
echo ""
echo "📌 OpenClaw has been restored to pre-hardening state"
echo "🔄 Please restart OpenClaw: openclaw restart"
echo ""
