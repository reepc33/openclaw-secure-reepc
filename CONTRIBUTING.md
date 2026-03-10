# Contributing to OpenClaw Secure

Thank you for your interest in contributing to OpenClaw Secure! This document provides guidelines for contributing to this project.

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to:

- Be respectful and inclusive
- Accept constructive criticism gracefully
- Focus on what is best for the community

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report, please:

1. Check if the bug has already been reported
2. Try to isolate the problem
3. Collect relevant information (OS, shell version, logs)

When reporting bugs, use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md).

### Suggesting Features

Feature suggestions are welcome! Please:

1. Check if the feature has already been suggested
2. Explain why this feature would be useful
3. Consider the security implications

Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md).

### Pull Requests

1. Fork the repository
2. Create a branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Run tests: `bash tests/test-all.sh`
5. Commit with clear messages
6. Push to your fork
7. Open a Pull Request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/openclaw-secure.git
cd openclaw-secure

# Run tests
bash tests/test-all.sh
```

## Style Guidelines

### Shell Scripts

- Use `#!/bin/bash` with `set -euo pipefail`
- Quote all variables: `"$variable"`
- Use functions for reusable code
- Add comments for complex logic
- Run `shellcheck` before submitting

Example:

```bash
#!/bin/bash
set -euo pipefail

my_function() {
    local param="$1"
    echo "Processing: $param"
}
```

### Commit Messages

- Use present tense: "Add feature" not "Added feature"
- Use imperative mood: "Move cursor to..." not "Moves cursor to..."
- Limit first line to 72 characters
- Reference issues when applicable

Examples:

```
Add firewall configuration option

Fix stat compatibility on macOS

Update security guidelines for skills

Closes #123
```

## Testing

All contributions should include tests where applicable:

```bash
# Run all tests
cd tests
bash test-all.sh

# Test specific script
bash test-install.sh
```

## Security Considerations

When contributing security-related changes:

1. Consider backward compatibility
2. Document any breaking changes
3. Update SECURITY.md if needed
4. Test on multiple platforms
5. Consider the threat model

## Documentation

- Update README.md if adding user-facing features
- Update CHANGELOG.md for all changes
- Add comments to complex code
- Keep AGENTS.md up to date

## Review Process

Pull requests will be reviewed for:

1. Code quality and style
2. Security implications
3. Test coverage
4. Documentation completeness
5. Cross-platform compatibility

## Questions?

Feel free to open an issue for questions or join discussions.

Thank you for contributing!
