# Changelog

All notable changes to SmartRails will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Complete test suite with RSpec
- Code coverage reports with SimpleCov
- API documentation with YARD
- Continuous Integration with GitHub Actions
- Gem signing for enhanced security
- Performance benchmarks
- Structured logging system
- Plugin architecture documentation
- Parallel audit processing
- Additional export formats (CSV, XML)
- Integration hooks (pre/post audit)
- Result caching system

## [0.3.0] - 2024-01-01

### Added
- Web interface with Sinatra for viewing reports
- HTML report generation with responsive design
- LLM integration for code suggestions (Ollama, OpenAI)
- Interactive audit mode with TTY::Prompt
- Auto-fix capability for common issues
- Database performance audits
- Comprehensive security audits (CSRF, SSL, SQL injection)
- Code quality metrics and suggestions
- Performance optimization recommendations

### Changed
- Improved CLI interface with colored output
- Enhanced error handling and user feedback
- Better configuration management via .smartrails.json
- More detailed audit reports

### Fixed
- Various bug fixes and performance improvements
- Better Rails app detection
- Improved compatibility with Rails 6+ and Ruby 3+

## [0.2.0] - 2023-06-15

### Added
- Performance auditor for Rails applications
- JSON report generation
- Basic LLM integration with Ollama
- Configuration file support
- Progress indicators with TTY::Spinner

### Changed
- Refactored auditor architecture for extensibility
- Improved modularity of codebase
- Better separation of concerns

## [0.1.0] - 2023-01-10

### Added
- Initial release of SmartRails
- Basic security auditor
- Basic code quality auditor
- Thor-based CLI framework
- Simple text-based reporting
- Rails project detection
- Basic auto-fix functionality

[Unreleased]: https://github.com/smartrails/smartrails/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/smartrails/smartrails/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/smartrails/smartrails/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/smartrails/smartrails/releases/tag/v0.1.0