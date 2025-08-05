# SmartRails 🚂

[![Gem Version](https://badge.fury.io/rb/smartrails.svg)](https://badge.fury.io/rb/smartrails)
[![Build Status](https://github.com/smartrails/smartrails/workflows/CI/badge.svg)](https://github.com/smartrails/smartrails/actions)
[![Code Climate](https://codeclimate.com/github/smartrails/smartrails/badges/gpa.svg)](https://codeclimate.com/github/smartrails/smartrails)
[![Test Coverage](https://codeclimate.com/github/smartrails/smartrails/badges/coverage.svg)](https://codeclimate.com/github/smartrails/smartrails/coverage)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

SmartRails is a professional CLI tool for Ruby on Rails applications that provides comprehensive auditing, monitoring, and maintenance capabilities. It helps developers identify security vulnerabilities, performance bottlenecks, code quality issues, and provides AI-powered suggestions for improvements.

## 🎯 Features

- **🔒 Security Auditing**: Automated detection of common security vulnerabilities (CSRF, SQL injection, hardcoded secrets, etc.)
- **📊 Code Quality Analysis**: Identifies code smells, missing tests, and Rails best practices violations
- **⚡ Performance Auditing**: Detects N+1 queries, missing indexes, caching issues, and asset optimization problems
- **🤖 AI-Powered Suggestions**: Integrates with Ollama, OpenAI, and other LLMs for intelligent code improvement suggestions
- **🔧 Auto-Fix Capabilities**: Automatically fixes common issues with triple security architecture (snapshot → apply → validate → rollback)
- **🛡️ Triple Security Architecture**: Safe automatic fixes with Git branching, snapshots, and rollback capabilities
- **🔍 Dry-Run Mode**: Preview changes before applying fixes
- **📈 Beautiful Reports**: Generates detailed HTML and JSON reports with actionable insights
- **🌐 Web Interface**: Available as separate `smartrails-web` gem for modular architecture
- **🎨 Customizable**: Extensible architecture for adding custom auditors and rules
- **⚡ High Performance**: Parallel processing and comprehensive test coverage (90%+)

## 📦 Installation

### Via RubyGems

```bash
gem install smartrails
```

### Via Bundler

Add this line to your application's Gemfile:

```ruby
gem 'smartrails', group: :development
```

Then execute:

```bash
bundle install
```

### From Source

```bash
git clone https://github.com/smartrails/smartrails.git
cd smartrails
bundle install
rake install
```

## 🚀 Quick Start

### Initialize SmartRails in your Rails project

```bash
cd your-rails-project
smartrails init my_project
```

### Run a comprehensive audit

```bash
smartrails audit
```

### Apply automatic fixes safely

```bash
# Preview fixes without applying (dry-run mode)
smartrails fix --dry-run

# Apply only safe fixes automatically
smartrails fix --level safe --auto-apply-safe

# Apply all fixes with confirmation prompts
smartrails fix --level risky
```

### View reports in web interface *(Requires smartrails-web gem)*

```bash
# Install web interface gem
gem install smartrails-web

# Launch web server
smartrails-web serve
# Open http://localhost:4567 in your browser
```

## 📖 Usage

### Available Commands

#### `smartrails init PROJECT_NAME`
Initialize SmartRails for a new or existing Rails project.

```bash
smartrails init my_app
```

#### `smartrails audit [OPTIONS]`
Run a comprehensive audit of your Rails application.

Options:
- `--only PHASES`: Run only specific phases (security, quality, database, performance, cleanup)
- `--skip PHASES`: Skip specific phases
- `--format FORMATS`: Output formats (json, html, markdown, badge, ci, sarif) [default: json]
- `--output DIR`: Output directory for reports
- `--ai`: Enable AI analysis and recommendations [default: true]
- `--interactive`: Interactive mode with confirmations [default: true]

```bash
# Interactive audit
smartrails audit

# Security-only audit
smartrails audit --only security

# Generate multiple report formats
smartrails audit --format json,html,markdown

# CI/CD mode with SARIF output
smartrails audit --format ci,sarif --interactive false
```

#### `smartrails fix [OPTIONS]`
Apply automatic fixes to detected issues with triple security architecture.

Safety levels:
- `safe`: Apply only safe, non-breaking fixes automatically
- `risky`: Apply all fixes with confirmation prompts
- `all`: Apply all auto-fixable issues (dangerous!)

Options:
- `--level LEVEL`: Safety level (safe, risky, all) [default: safe]
- `--dry-run`: Preview changes without applying
- `--rollback SNAPSHOT_ID`: Rollback to specific snapshot ID
- `--list-snapshots`: List available snapshots
- `--auto-apply-safe`: Auto-apply safe fixes without confirmation

```bash
# Preview fixes (dry-run mode)
smartrails fix --dry-run

# Apply safe fixes automatically
smartrails fix --level safe --auto-apply-safe

# Apply all fixes with prompts
smartrails fix --level risky

# List available snapshots for rollback
smartrails fix --list-snapshots

# Rollback to specific snapshot
smartrails fix --rollback snapshot_abc123
```

#### `smartrails suggest [SOURCE] [OPTIONS]`
Get AI-powered suggestions for code improvements.

Options:
- `-f, --file FILE`: Path to file to analyze
- `-a, --audit-results FILE`: Path to audit results JSON file
- `-l, --llm MODEL`: LLM provider (ollama, openai, claude, mistral) [default: ollama]
- `-m, --model NAME`: Specific model name to use
- `--stream`: Stream response in real-time [default: true]

```bash
# Analyze a specific file
smartrails suggest --file app/controllers/users_controller.rb

# Use latest audit report
smartrails suggest --audit-results tmp/smartrails_reports/smartrails_audit.json

# Use Claude with streaming
smartrails suggest --llm claude --model claude-3-sonnet --stream

# Ask a specific question
smartrails suggest "How to improve security in Rails?"
```

#### `smartrails badge [OPTIONS]`
Generate and manage SmartRails quality badges.

Badge levels: Platinum (95%+), Gold (85%+), Silver (75%+), Bronze (65%+), Certified (50%+)

Options:
- `--update-readme`: Automatically update README with badge
- `--format FORMAT`: Badge format (markdown, html, svg) [default: markdown]
- `--audit-file FILE`: Path to audit results file

```bash
# Generate badge for latest audit
smartrails badge

# Update README automatically
smartrails badge --update-readme

# Generate SVG badge
smartrails badge --format svg
```

#### `smartrails serve` *(Moved to separate gem)*

The web interface functionality has been moved to a separate gem `smartrails-web` for better modularity.

Install separately:
```bash
gem install smartrails-web
```

Then use:
```bash
smartrails-web serve --port 4567
```

See `/web_gem_extract/` for the extracted web components.

#### `smartrails check:llm`
Verify LLM connection and configuration.

```bash
smartrails check:llm
```

## 🛡️ Triple Security Architecture

SmartRails implements a comprehensive triple security architecture for safe automatic fixes:

### 1. **Snapshot Creation** 📸
Before applying any fixes, SmartRails creates a complete snapshot of your project state:
- File system snapshot with timestamps
- Git commit hash recording
- Project integrity checksum

### 2. **Safe Application** ⚡
Fixes are applied using a sophisticated safety system:
- **Safe Fixes**: RuboCop style issues, whitespace, formatting - applied automatically
- **Risky Fixes**: Security issues, dependency updates - require user confirmation
- **Git Branching**: Each fix session creates a dedicated Git branch
- **Parallel Processing**: Multiple fixes applied efficiently

### 3. **Validation & Rollback** ✅
Every fix is validated before being made permanent:
- **Syntax Validation**: Ruby syntax checking
- **Rails Application Validation**: Ensures Rails app still boots
- **Test Suite Validation**: Critical tests must pass (if available)
- **Automatic Rollback**: Failed fixes are automatically reverted
- **Manual Rollback**: Use `--rollback` to restore any previous snapshot

```bash
# Example workflow
smartrails audit                           # Discover issues
smartrails fix --dry-run                   # Preview fixes
smartrails fix --level safe                # Apply safe fixes with confirmation
smartrails fix --list-snapshots           # View available rollback points
smartrails fix --rollback snapshot_abc123  # Rollback if needed
```

### Rollback Capabilities
```bash
# List all available snapshots
smartrails fix --list-snapshots

# Rollback to specific snapshot
smartrails fix --rollback snapshot_20240101_143022

# Example output:
# 📸 Available Snapshots
# 1. snapshot_20240101_143022
#    Description: Before applying RuboCop fixes
#    Created: 2024-01-01 14:30:22
#    Files: 127
#    Git Commit: a1b2c3d
```

## 🔍 What SmartRails Audits

### Security Checks
- CSRF protection configuration
- SQL injection vulnerabilities
- Hardcoded secrets and credentials
- SSL/TLS configuration
- Authentication and authorization setup
- Security headers implementation

### Code Quality Checks
- Test coverage and presence
- Code documentation
- Linting configuration
- Dependency management
- Rails best practices
- Database migrations quality

### Performance Checks
- N+1 query detection
- Missing database indexes
- Caching configuration
- Asset optimization
- Background job setup
- Pagination implementation

## 🤖 AI Integration

SmartRails supports multiple LLM providers for intelligent code analysis:

### Ollama (Local)
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull a model
ollama pull llama3

# Use with SmartRails
smartrails suggest --llm ollama
```

### OpenAI
```bash
# Set API key
export OPENAI_API_KEY=your-api-key

# Use with SmartRails
smartrails suggest --llm openai --model gpt-4
```

## ⚙️ Configuration

SmartRails uses a `.smartrails.json` file for project-specific configuration:

```json
{
  "name": "my_project",
  "version": "0.3.0",
  "features": ["security", "performance", "quality"],
  "rails_version": "7.0.4",
  "ruby_version": "3.2.0",
  "custom_rules": {
    "security": {
      "check_api_authentication": true
    }
  }
}
```

### Environment Variables

- `OLLAMA_MODEL`: Default Ollama model (default: llama3)
- `OPENAI_API_KEY`: OpenAI API key for GPT models
- `SMARTRAILS_REPORTS_DIR`: Custom reports directory

## 🧩 Extending SmartRails

### Creating Custom Auditors

Create a new auditor by extending `SmartRails::Auditors::BaseAuditor`:

```ruby
# lib/smartrails/auditors/custom_auditor.rb
module SmartRails
  module Auditors
    class CustomAuditor < BaseAuditor
      def run
        # Your audit logic here
        check_custom_issue
        
        issues
      end
      
      private
      
      def check_custom_issue
        if some_condition?
          add_issue(
            type: 'Custom Issue',
            message: 'Description of the issue',
            severity: :medium,
            file: 'path/to/file.rb',
            auto_fix: -> { fix_custom_issue }
          )
        end
      end
      
      def fix_custom_issue
        # Auto-fix implementation
      end
    end
  end
end
```

## 📊 Report Examples

### JSON Report Structure
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "0.3.0",
  "summary": "Found 5 high severity issues that should be addressed soon.",
  "statistics": {
    "total": 12,
    "by_severity": {
      "critical": 0,
      "high": 5,
      "medium": 4,
      "low": 3
    },
    "auto_fixable": 8
  },
  "issues": [
    {
      "type": "CSRF Protection",
      "message": "CSRF protection is not enabled in ApplicationController",
      "severity": "high",
      "file": "app/controllers/application_controller.rb",
      "auto_fixable": true
    }
  ]
}
```

## 🛠️ Development

### Setup Development Environment

```bash
git clone https://github.com/smartrails/smartrails.git
cd smartrails
bundle install
```

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with coverage
bundle exec rspec --format documentation

# Run specific test file
bundle exec rspec spec/smartrails/auditors/security_auditor_spec.rb
```

### Code Quality

```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix RuboCop issues
bundle exec rubocop -a

# Run all quality checks
bundle exec rake quality
```

### Building the Gem

```bash
bundle exec rake build
```

## 🏛️ Governance

This project is maintained by **OASIISBOX**. For detailed governance information, see [GOVERNANCE.md](GOVERNANCE.md).

- **Maintainer**: OASIISBOX.SmartRailsDEV
- **Contribution Review**: All contributions require maintainer approval
- **Merge Authority**: Only official maintainers can merge PRs or publish releases
- **Final Authority**: All project decisions are subject to maintainer review and approval

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

**Important**: All contributions must include a Developer Certificate of Origin (DCO) sign-off and will be reviewed by our maintainers before integration.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes with DCO sign-off (`git commit -s -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request (subject to maintainer review)

### Developer Certificate of Origin

By contributing to this project, you certify that you have the right to submit your work under the project's open source license. All commits must include a `Signed-off-by` line with your real name and email address.

**Note**: Acceptance of contributions is at the sole discretion of the project maintainers.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Rails community for inspiration and best practices
- Contributors and users who help improve SmartRails
- Open source projects that make this possible

## 📮 Support

- 📧 Email: support@smartrails.dev
- 🐛 Issues: [GitHub Issues](https://github.com/smartrails/smartrails/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/smartrails/smartrails/discussions)
- 📖 Documentation: [smartrails.dev/docs](https://smartrails.dev/docs)

## 🗺️ Roadmap

- [ ] Support for Rails 8.0
- [ ] Integration with CI/CD pipelines
- [ ] Custom rule marketplace
- [ ] Performance benchmarking
- [ ] Visual dependency analysis
- [ ] Multi-project dashboard
- [ ] Docker support
- [ ] VS Code extension

---

Made with ❤️ by the Rails community