# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 3.1.x   | :white_check_mark: |
| < 3.1   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Do NOT open a public issue.** Instead, contact the maintainers privately via GitHub's [Security Advisory](https://docs.github.com/en/code-security/security-advisories) feature on this repository.

### What to include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response timeline

- **Acknowledgment**: within 48 hours
- **Initial assessment**: within 7 days
- **Fix or mitigation**: within 30 days for confirmed vulnerabilities

## Security Best Practices for Users

1. **Never commit `.env` files** — use `.env.example` as a template
2. **Rotate secrets regularly** — especially `JWT_SECRET` and database passwords
3. **Use HTTPS in production** — the development config allows cleartext only for `10.0.2.2` (Android emulator loopback)
4. **Keep dependencies updated** — run `npm audit` regularly for the backend
5. **Review skill files before use** — skills contain executable patterns; inspect before applying to your projects
