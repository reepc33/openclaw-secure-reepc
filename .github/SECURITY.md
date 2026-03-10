# Security Policy

## Reporting Security Vulnerabilities

We take security seriously. If you discover a security vulnerability in this project, please report it responsibly.

### How to Report

1. **DO NOT** open a public issue for security vulnerabilities
2. Email security concerns to: [Create a GitHub issue with "SECURITY" label] or contact the maintainer directly
3. Provide detailed information about the vulnerability:
   - Type of vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Response Time

- Acknowledgment: Within 48 hours
- Initial assessment: Within 7 days
- Fix timeline: Depends on severity
  - Critical: 7 days
  - High: 14 days
  - Medium: 30 days
  - Low: Next release

### Security Measures

This project implements the following security measures:

1. **Configuration Hardening**
   - Localhost-only binding (127.0.0.1)
   - Authentication token generation
   - Disabled dangerous tools (file_delete, shell_execute)

2. **File Permissions**
   - Config files: 600 (owner read/write only)
   - Directories: 700 (owner full access only)

3. **Audit Trail**
   - Security audit script
   - Configuration hash verification
   - Operation logging

4. **Supply Chain Protection**
   - Disabled auto-updates
   - Trusted-only skills policy
   - Skill installation confirmation

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Known Security Considerations

### Token Storage

The authentication token is stored in:
- `~/.openclaw/openclaw.json` (configuration file)
- `~/.openclaw/.auth_token` (token file, 600 permissions)

**Recommendation**: Consider using environment variables for production deployments:

```bash
export OPENCLAW_TOKEN=$(cat ~/.openclaw/.auth_token)
```

### Network Exposure

OpenClaw gateway binds to `127.0.0.1:18789` by default.

**Never** expose this port to the public internet without:
- Reverse proxy with authentication
- VPN access only
- Firewall rules blocking external access

### Skill Security

Third-party skills can introduce vulnerabilities:

1. Always review skill code before installation
2. Use `clawhub inspect` to examine skill contents
3. Install only from trusted sources
4. Regularly audit installed skills

## Security Best Practices

### For Users

1. Run regular security audits: `~/.openclaw/workspace/scripts/security-audit.sh`
2. Keep OpenClaw updated to latest stable version
3. Review AGENTS.md safety guidelines regularly
4. Monitor audit logs: `tail -f ~/.openclaw/logs/audit.log`
5. Use firewall to block port 18789 from external access

### For Contributors

1. Run shellcheck before submitting: `shellcheck *.sh`
2. Test on multiple platforms (Linux, macOS, WSL)
3. Follow least privilege principle
4. Document security implications of changes

## Disclosure Policy

We follow responsible disclosure:

1. Reporter submits vulnerability privately
2. We acknowledge receipt and begin investigation
3. We develop and test a fix
4. We coordinate disclosure timeline with reporter
5. We release fix and publicly disclose

## Acknowledgments

We appreciate security researchers who help improve this project responsibly.

---

**Last Updated**: 2026-03-10
