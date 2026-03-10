# Changelog

All notable changes to this project will be documented in this file.

## [v1.0.0] - 2026-03-10

### Initial Release
- Basic security hardening functionality
- One-click installation script (install.sh)
- Core initialization script (secure-init.sh)
- Safe uninstall script (uninstall.sh)
- Security audit script (security-audit.sh)
- Configuration file protection (permissions 600/700)
- Automatic secure token generation
- AI safety guidelines (AGENTS.md)
- Disable dangerous features (file_delete, shell_execute)
- Network access restriction (localhost 127.0.0.1 only)
- Optional automatic daily security audit

### Security Features
- Configuration baseline hash verification
- Sensitive file scanning
- Plaintext credential detection
- Automatic permission repair suggestions
