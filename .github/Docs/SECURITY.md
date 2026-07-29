# Security Policy

## Supported Versions

| Version | Supported        |
| ------- | ---------------- |
| 2.5.x   | ✅ Yes           |
| < 2.5   | ❌ No            |

## Reporting Vulnerabilities

> [!CAUTION]
> **Do NOT open public issues for security vulnerabilities.**
> Opening a public issue exposes users to risks before a fix is available.

### How to Report

Send a **private report** through one of the following channels:

- **GitHub Security Advisories:** use the [Report a vulnerability](../../security/advisories/new) feature directly in this repository.
- **Email:** [me@magnetarman.com](mailto:me@magnetarman.com) — include `[SECURITY] WinToolkit` in the subject line.

### What to Include in the Report

To speed up verification and resolution, include:

1. Clear description of the vulnerability
2. Steps to reproduce (step-by-step)
3. Estimated potential impact
4. Version of WinToolkit affected
5. Any proof-of-concept (privately, only)

### Response Times

| Phase                          | Timeline       |
| -------------------------------| --------------- |
| Confirmation of receipt        | Within 72 hours |
| Initial assessment             | Within 7 days   |
| Fix and patch release          | Within 30 days  |
| Public disclosure (CVE)        | After the fix   |

### Scope

The following are considered **in scope**:

- Arbitrary code execution via the toolkit
- Unintended privilege escalation
- Missing or bypassable checksum verification for distributed binaries
- Vulnerabilities in CI/CD workflows that allow supply chain compromise

The following are considered **out of scope**:

- Expected behaviors that already require administrative privileges
- Vulnerabilities in unsupported versions (< 2.5)
- Vulnerabilities in third-party dependencies not managed by this project

---

Thank you for contributing to the security of WinToolkit.