# OpenClaw Secure

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-v1.0.0-blue.svg)]()

One-click security hardening for OpenClaw local deployment.

**OpenClaw 本地部署一键安全加固工具**

---

## ✨ Features

- [x] **One-click security hardening** - Automated secure configuration
- [x] **Automatic token generation** - Strong random authentication token
- [x] **File permission protection** - 600/700 secure permissions
- [x] **Security audit script** - 10-point automated security check
- [x] **AI safety guidelines** - Comprehensive AGENTS.md rules
- [x] **Dangerous features disabled** - file_delete, shell_execute blocked
- [x] **Audit logging** - Complete operation tracking
- [x] **Optional auto-audit** - Daily automated security scans

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/reepc33/openclaw-secure.git
cd openclaw-secure

# Run installer
bash install.sh
```

## 📋 Prerequisites

Before installation, ensure you have:

- **Bash** (any modern version)
- **OpenClaw** installed (`npm install -g @openclaw/cli`)
- **openssl** (for token generation)
- **curl** (for update checking)

⚠️ **Important**: Do **not** run as root. The script will reject root execution.

## 🔧 Usage

### Run Security Audit

```bash
# Manual audit
~/.openclaw/workspace/scripts/security-audit.sh

# View latest report
cat /tmp/openclaw-security-reports/latest-summary.txt
```

### Edit Safety Guidelines

```bash
nano ~/.openclaw/workspace/AGENTS.md
```

### View Configuration

```bash
cat ~/.openclaw/openclaw.json
```

## 🗑️ Uninstall

```bash
bash uninstall.sh
```

The uninstaller will:
- Ask before each action
- Optionally restore original configuration
- Remove cron jobs
- Keep your OpenClaw data intact

## ⚠️ Security Notes

1. **Never run as root** - OpenClaw should run as regular user
2. **Keep auth token secret** - Never share `~/.openclaw/openclaw.json`
3. **Review AGENTS.md regularly** - Update safety guidelines as needed
4. **Run audit weekly** - Check security status regularly
5. **Backup important data** - Before any major changes

## 🔐 Configuration

Key security settings applied by this tool:

| Setting | Value | Purpose |
|---------|-------|---------|
| `gateway.host` | `127.0.0.1` | Localhost only, no public exposure |
| `tools.file_delete` | `false` | Prevent accidental/malicious deletion |
| `tools.shell_execute` | `false` | Prevent command injection |
| `agents.confirmationRequired` | `true` | Human confirmation for risky ops |
| `skills.autoUpdate` | `false` | Prevent supply chain attacks |

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## 🐛 Issue Reporting

Found a bug or have a suggestion? Please open an issue:

https://github.com/reepc33/openclaw-secure/issues

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 🙏 Acknowledgments

- OpenClaw community for the amazing AI agent framework
- Security researchers who disclosed vulnerabilities and best practices
- Contributors who helped improve this tool

---

**Disclaimer**: This tool provides security hardening recommendations. Always review changes before applying to production systems. The authors are not responsible for any data loss or security incidents.
