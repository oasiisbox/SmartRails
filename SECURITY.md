# Security Policy

## Supported Versions

We take security seriously and provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 0.3.x   | ✅ Yes             |
| 0.2.x   | ❌ No              |
| < 0.2   | ❌ No              |

## Reporting a Vulnerability

We appreciate your efforts to responsibly disclose security vulnerabilities. Please follow these guidelines:

### How to Report

1. **Do NOT** create a public GitHub issue for security vulnerabilities
2. Email security concerns to: **lanoix.pascal@gmail.com**
3. Include "SECURITY" in the subject line
4. Provide detailed information about the vulnerability

### What to Include

Please include the following information in your report:

- A clear description of the vulnerability
- Steps to reproduce the issue
- Potential impact and exploitation scenarios
- Any suggested fixes or mitigations
- Your contact information for follow-up

### Response Timeline

- **Initial Response**: Within 48 hours of receiving your report
- **Assessment**: Within 7 days, we'll provide an initial assessment
- **Fix Timeline**: Critical vulnerabilities will be addressed within 30 days
- **Disclosure**: We'll coordinate with you on responsible disclosure timing

### What Happens Next

1. We'll acknowledge your report and begin investigation
2. We'll work to understand and reproduce the issue
3. We'll develop and test a fix
4. We'll prepare a security advisory
5. We'll release the fix and publish the advisory
6. We'll credit you for the discovery (if desired)

## Security Measures

SmartRails implements several security practices:

- Regular dependency updates and vulnerability scanning
- Automated security testing in CI/CD pipeline
- Code review requirements for all changes
- Secure coding practices and linting rules
- Limited scope of operations (read-only analysis)

## Scope

This security policy applies to:

- The SmartRails CLI tool and its core functionality
- The web interface for report viewing
- Integration with external LLM services
- All dependencies and third-party components

## Out of Scope

The following are typically considered out of scope:

- Issues in dependencies that don't affect SmartRails functionality
- Theoretical vulnerabilities without proof of concept
- Social engineering attacks
- Physical access to systems running SmartRails

## Security Best Practices for Users

When using SmartRails:

1. Keep the gem updated to the latest version
2. Run `bundle audit` regularly to check for dependency vulnerabilities
3. Use secure API keys for LLM services
4. Review generated reports before sharing externally
5. Be cautious when using auto-fix features in production

## Contact

For security-related questions or concerns:

- **Email**: lanoix.pascal@gmail.com
- **Subject**: [SECURITY] Your concern
- **PGP Key**: Available upon request

Thank you for helping keep SmartRails secure! 🔒