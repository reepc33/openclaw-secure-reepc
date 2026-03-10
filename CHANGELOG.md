# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Cross-platform support (Linux, macOS, WSL)
- System detection at installation start
- Node.js and npm version checking
- OpenClaw version detection
- Firewall configuration (UFW/iptables)
- Improved token storage (separate .auth_token file)
- Enhanced backup strategy (AGENTS.md and scripts)
- GitHub Actions CI/CD (ShellCheck)
- Security Policy (SECURITY.md)
- Contributing guidelines (CONTRIBUTING.md)
- Issue templates (Bug Report, Feature Request, Security Issue)
- Comprehensive test suite
- Docker support documentation
- Better error handling with logging

### Changed
- Improved install.sh compatibility (POSIX-compliant read)
- Fixed stat command compatibility for macOS/BSD
- Added curl timeout for update checking
- Replaced `2>/dev/null || true` with proper error handling
- Enhanced security audit with cross-platform checks
- Improved crontab service reload on uninstall

### Security
- Added tokenSource field to configuration
- Separated token storage from config file
- Enhanced file permission checks
- Added AGENTS.md hash verification

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

[Unreleased]: https://github.com/reepc33/openclaw-secure/compare/v1.0.0...HEAD
[v1.0.0]: https://github.com/reepc33/openclaw-secure/releases/tag/v1.0.0
