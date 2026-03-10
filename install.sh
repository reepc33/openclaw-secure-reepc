#!/bin/bash
#
# OpenClaw Secure - Entry Installation Script
# Version: v1.0.0
# Repository: https://github.com/reepc33/openclaw-secure
#

set -e

VERSION="v1.0.0"
REPO="reepc33/openclaw-secure"

echo ""
echo "🛡️  OpenClaw Secure Installer"
echo "================================"
echo "Version: $VERSION"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Do not run this script as root"
    echo "   Please switch to a regular user and try again"
    exit 1
fi

# Check dependencies
echo "📋 Checking dependencies..."

deps=(bash openssl curl sha256sum)
for d in "${deps[@]}"; do
    if ! command -v $d >/dev/null 2>&1; then
        echo "❌ Missing dependency: $d"
        echo "   Please install $d first"
        exit 1
    fi
done

# Check OpenClaw
if ! command -v openclaw >/dev/null 2>&1; then
    echo "❌ OpenClaw not detected"
    echo ""
    echo "Please install OpenClaw first:"
    echo "   npm install -g @openclaw/cli"
    echo ""
    exit 1
fi

echo "✅ Environment check passed"

# Check for updates
echo ""
echo "🔍 Checking for updates..."
LATEST=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [ -n "$LATEST" ] && [ "$LATEST" != "$VERSION" ]; then
    echo "⚠️  New version available: $LATEST, current: $VERSION"
    echo "   Download: https://github.com/$REPO/releases"
    echo ""
    read -p "Continue with current version? [Y/n] " continue_old
    if [[ "$continue_old" == "n" ]]; then
        echo "Cancelled, please download the new version"
        exit 0
    fi
else
    echo "✅ Already up to date"
fi

# Show what will be done
echo ""
echo "⚠️  This script will perform the following operations:"
echo "   1. Backup existing config to ~/.openclaw/backup/"
echo "   2. Create secure openclaw.json (disable dangerous features)"
echo "   3. Create AGENTS.md security guidelines"
echo "   4. Set file permissions to 600/700"
echo "   5. Generate config hash baseline"
echo "   6. Create security audit script"
echo "   7. Optional: Add daily automatic security audit"
echo ""
read -p "Continue installation? [Y/n] " confirm

if [[ "$confirm" == "n" ]]; then
    echo "Installation cancelled"
    exit 0
fi

# Execute core installation
echo ""
echo "🚀 Starting installation..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/secure-init.sh"

# Ask about cron job
echo ""
read -p "Add daily automatic security audit (3 AM)? [Y/n] " add_cron
if [[ "$add_cron" != "n" ]]; then
    CRON_CMD="0 3 * * * /bin/bash $HOME/.openclaw/workspace/scripts/security-audit.sh >> /tmp/openclaw-cron.log 2>&1"
    
    # Check if already exists
    if crontab -l 2>/dev/null | grep -q "security-audit.sh"; then
        echo "ℹ️  Cron job already exists, skipping"
    else
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
        echo "✅ Daily audit cron job added"
    fi
fi

# Completion message
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
echo ""
