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
- **🔧 Auto-Fix Capabilities**: Automatically fixes common issues with a single command
- **📈 Beautiful Reports**: Generates detailed HTML and JSON reports with actionable insights
- **🌐 Web Interface**: Built-in web server to view and manage reports
- **🎨 Customizable**: Extensible architecture for adding custom auditors and rules

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

### Run audit with automatic fixes

```bash
smartrails audit --auto
```

### View reports in web interface

```bash
smartrails serve
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
- `--auto`: Run audit without user interaction
- `--fix`: Automatically fix issues when possible
- `--format FORMAT`: Output format (json, html) [default: json]

```bash
# Interactive audit
smartrails audit

# Automatic audit with fixes
smartrails audit --auto --fix

# Generate HTML report
smartrails audit --format html
```

#### `smartrails suggest [SOURCE] [OPTIONS]`
Get AI-powered suggestions for code improvements.

Options:
- `-f, --file FILE`: Path to file to analyze
- `-l, --llm MODEL`: LLM model to use (ollama, openai, mistral) [default: ollama]
- `-m, --model NAME`: Specific model name to use

```bash
# Analyze a specific file
smartrails suggest --file app/controllers/users_controller.rb

# Use latest audit report
smartrails suggest

# Use OpenAI GPT-4
smartrails suggest --llm openai --model gpt-4
```

#### `smartrails serve [OPTIONS]`
Launch a local web interface to view and manage reports.

Options:
- `-p, --port PORT`: Port to run the server on [default: 4567]
- `-h, --host HOST`: Host to bind to [default: localhost]

```bash
# Start web server
smartrails serve

# Custom port
smartrails serve --port 8080
```

#### `smartrails check:llm`
Verify LLM connection and configuration.

```bash
smartrails check:llm
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

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

**Important**: All contributions must include a Developer Certificate of Origin (DCO) sign-off.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes with DCO sign-off (`git commit -s -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Developer Certificate of Origin

By contributing to this project, you certify that you have the right to submit your work under the project's open source license. All commits must include a `Signed-off-by` line with your real name and email address.

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