# OpenClaw Secure

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-v1.0.0-blue.svg)]()
[![ShellCheck](https://github.com/reepc33/openclaw-secure/actions/workflows/shellcheck.yml/badge.svg)]()

> ⚠️ **DISCLAIMER: This is NOT an official OpenClaw project.**
> 
> This is a community security hardening toolkit for local OpenClaw deployments.
> It is not affiliated with, endorsed by, or connected to the official OpenClaw project.

One-click security hardening for OpenClaw local deployment.

**OpenClaw 本地部署一键安全加固工具**

---

## 🛡️ Threat Model

This tool protects against the following attack vectors:

| Threat | Protection |
|--------|------------|
| **Exposed Gateway** | Binds to 127.0.0.1 only, blocks public network access |
| **Prompt Injection** | AGENTS.md with strict command filtering rules |
| **Malicious Skills** | Disabled auto-update, install confirmation required |
| **Credential Leakage** | Secure token generation, file permissions 600/700 |
| **Command Injection** | Disabled shell_execute, file_delete tools |
| **Supply Chain Attacks** | Trusted-only skills, no auto-updates |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      User Layer                        │
│         (Human oversight and confirmation)             │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                  OpenClaw Gateway                      │
│              127.0.0.1:18789 (localhost only)          │
└─────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   AGENTS.md  │  │  Security    │  │   Token      │
│   (Safety    │  │  Config      │  │   Auth       │
│   Rules)     │  │  (Hardened)  │  │   (Secure)   │
└──────────────┘  └──────────────┘  └──────────────┘
```

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
- [x] **Cross-platform support** - Linux, macOS, WSL compatible
- [x] **Firewall configuration** - Optional UFW/iptables rules

---

## 🚀 Quick Start

**⚠️ Important: Choose Your Installation Method**

This toolkit provides **two independent installation methods**. Choose based on your situation:

| Method | When to Use | Prerequisites |
|--------|-------------|---------------|
| **Standard** | You already have OpenClaw installed | OpenClaw CLI (npm) |
| **Docker** | You want isolated container deployment | Docker & Docker Compose |

---

### Option 1: Standard Installation (Most Common)

**Use this if:** You have OpenClaw already installed via npm and want to secure it.

```bash
# 1. Clone the repository
git clone https://github.com/reepc33/openclaw-secure.git
cd openclaw-secure

# 2. Run the security hardening installer
bash install.sh

# Done! Your existing OpenClaw is now secured.
```

**What this does:**
- ✅ Hardens your **existing** OpenClaw installation
- ✅ Backs up current config to `~/.openclaw/backup/`
- ✅ Generates secure token and applies security policies
- ✅ Sets file permissions to 600/700

---

### Option 2: Docker Installation (Isolated Environment)

**Use this if:** You want OpenClaw to run in an isolated container (recommended for servers).

```bash
# 1. Clone the repository
git clone https://github.com/reepc33/openclaw-secure.git
cd openclaw-secure

# 2. Start with Docker (auto-installs OpenClaw + applies hardening)
cd docker
docker-compose up -d

# Done! OpenClaw is running securely in a container.
```

**What this does:**
- ✅ Installs **fresh** OpenClaw instance in Docker container
- ✅ Automatically applies all security hardening
- ✅ Runs as non-root user with limited privileges
- ✅ Isolated from host system

---

### 🔄 Which Should I Choose?

```
Scenario 1: "I already use OpenClaw on my laptop"
→ Use Standard Installation (Option 1)

Scenario 2: "I'm setting up OpenClaw on a server"
→ Use Docker Installation (Option 2) 

Scenario 3: "I don't have OpenClaw yet"
→ Use Docker Installation (Option 2) - it's the fastest way

Scenario 4: "I want maximum security"
→ Use Docker Installation (Option 2) - provides better isolation
```

---

## 📋 Prerequisites

Prerequisites depend on your chosen installation method:

### For Standard Installation

- **Linux, macOS, or WSL** (Windows Subsystem for Linux)
- **Bash** 4.0+ (any modern version)
- **Node.js** 16+ and **npm**
- **OpenClaw** installed (`npm install -g @openclaw/cli`)
- **openssl** (for token generation)
- **curl** (for update checking)

⚠️ **Important**: Do **not** run as root. The script will reject root execution.

### For Docker Installation

- **Docker** 20.0+
- **Docker Compose** 2.0+
- That's it! OpenClaw will be installed automatically inside the container.

---

## 🔧 Usage

### Run Security Audit

```bash
# Manual audit
~/.openclaw/workspace/scripts/security-audit.sh

# View latest report
cat /tmp/openclaw-security-reports/latest-summary.txt
```

### Example Output

```
🛡️  OpenClaw Security Audit
====================

[1/10] Checking configuration baseline...
✅ Configuration not modified

[2/10] Checking file permissions...
✅ Config file permissions secure (600)

[3/10] Checking network listeners...
✅ Listening only on localhost

[4/10] Checking security configuration...
✅ Gateway bound to localhost only
✅ Authentication enabled
✅ File delete function disabled
✅ Shell execute function disabled

...

====================
🎉 All critical checks passed
====================
```

### Edit Safety Guidelines

```bash
nano ~/.openclaw/workspace/AGENTS.md
```

### View Configuration

```bash
cat ~/.openclaw/openclaw.json
```

### Configure Firewall (Optional)

```bash
# The installer can optionally configure UFW/iptables
# to block external access to port 18789
```

---

## 🗑️ Uninstall

**⚠️ Use the uninstall method that matches your installation:**

### Uninstall Standard Installation

If you used `bash install.sh` (Standard Installation):

```bash
# From project root
bash uninstall.sh
```

The uninstaller will:
- Ask before each action
- Optionally restore original configuration from backup
- Remove cron jobs
- Remove security hardening files
- Keep your OpenClaw installation intact

### Uninstall Docker Installation

If you used `docker-compose up -d` (Docker Installation):

```bash
# From project root
cd docker
docker-compose down

# Optional: Remove data volume (WARNING: This deletes all OpenClaw data)
docker volume rm openclaw-secure_openclaw-data
```

This will:
- Stop and remove the container
- Preserve data in Docker volumes (unless you delete them)
- Completely remove the isolated OpenClaw instance

---

## ⚠️ Security Notes

1. **Never run as root** - OpenClaw should run as regular user
2. **Keep auth token secret** - Never share `~/.openclaw/openclaw.json`
3. **Review AGENTS.md regularly** - Update safety guidelines as needed
4. **Run audit weekly** - Check security status regularly
5. **Backup important data** - Before any major changes
6. **Use firewall** - Block external access to port 18789
7. **Only install audited skills** - Review all skills before installation
8. **Consider Docker sandbox** - For additional isolation

---

## 🔐 Configuration

Key security settings applied by this tool:

| Setting | Value | Purpose |
|---------|-------|---------|
| `gateway.host` | `127.0.0.1` | Localhost only, no public exposure |
| `tools.file_delete` | `false` | Prevent accidental/malicious deletion |
| `tools.shell_execute` | `false` | Prevent command injection |
| `agents.confirmationRequired` | `true` | Human confirmation for risky ops |
| `skills.autoUpdate` | `false` | Prevent supply chain attacks |

---

## 🧪 Testing

```bash
# Run all tests
cd tests
bash test-all.sh

# Run specific test
bash test-install.sh
```

---

## 🐳 Docker Support (Alternative Installation)

Docker installation is a **complete alternative** to standard installation. It doesn't require OpenClaw to be pre-installed on your system.

### When to Use Docker

- ✅ **Clean slate**: Fresh OpenClaw installation without affecting host
- ✅ **Server deployment**: Better isolation and security on production servers  
- ✅ **No Node.js**: Don't want to install Node.js/npm on host system
- ✅ **Maximum security**: Container isolation + security hardening combined

### Quick Start with Docker

```bash
# From project root
cd docker
docker-compose up -d

# Check status
docker logs -f openclaw-secure
```

### Docker vs Standard: Key Differences

| Feature | Standard Install | Docker Install |
|---------|-----------------|----------------|
| **OpenClaw** | Must pre-install via npm | Auto-installed in container |
| **Data location** | `~/.openclaw/` on host | Docker volume |
| **Isolation** | Process-level | Container-level |
| **Node.js** | Required on host | Only in container |
| **Persistence** | Permanent on host | Survives container restarts |
| **Port binding** | Host localhost | Container → Host localhost |

### Docker Security Features

The Docker setup includes additional security layers:

- **Non-root user**: Runs as UID 1000 (not root)
- **Read-only filesystem**: Container filesystem is read-only
- **Capability dropping**: All capabilities removed except essential ones
- **No new privileges**: Prevents privilege escalation
- **Network isolation**: Separate bridge network

See `docker/README.md` for detailed configuration options.

---

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 🛡️ Security

See [SECURITY.md](.github/SECURITY.md) for security policies and reporting vulnerabilities.

---

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

---

## 🐛 Issue Reporting

Found a bug or have a suggestion? Please open an issue:

https://github.com/reepc33/openclaw-secure/issues

---

## 🙏 Acknowledgments

- OpenClaw community for the amazing AI agent framework
- Security researchers who disclosed vulnerabilities and best practices
- Contributors who helped improve this tool

---

**Disclaimer**: This tool provides security hardening recommendations. Always review changes before applying to production systems. The authors are not responsible for any data loss or security incidents.

This is a community project and is **not affiliated with the official OpenClaw project**.
