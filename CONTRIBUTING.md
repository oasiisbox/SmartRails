# Contributing to SmartRails

First off, thank you for considering contributing to SmartRails! It's people like you that make SmartRails such a great tool for the Rails community.

## Code of Conduct

By participating in this project, you are expected to uphold our Code of Conduct:

- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Gracefully accept constructive criticism
- Focus on what is best for the community
- Show empathy towards other community members

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples to demonstrate the steps**
- **Describe the behavior you observed after following the steps**
- **Explain which behavior you expected to see instead and why**
- **Include screenshots if possible**
- **Include your environment details** (Ruby version, Rails version, OS, etc.)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

- **Use a clear and descriptive title**
- **Provide a step-by-step description of the suggested enhancement**
- **Provide specific examples to demonstrate the steps**
- **Describe the current behavior and explain which behavior you expected to see instead**
- **Explain why this enhancement would be useful**

### Pull Requests

1. Fork the repo and create your branch from `main`:
   ```bash
   git checkout -b feature/amazing-feature
   ```

2. Make your changes following our coding standards

3. Add tests for your changes. We aim for 100% test coverage

4. Ensure the test suite passes:
   ```bash
   bundle exec rspec
   ```

5. Run RuboCop and fix any issues:
   ```bash
   bundle exec rubocop -a
   ```

6. Update documentation if needed

7. Commit your changes using a descriptive commit message:
   ```bash
   git commit -m 'Add some amazing feature'
   ```

8. Push to your fork:
   ```bash
   git push origin feature/amazing-feature
   ```

9. Open a Pull Request

## Development Setup

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/your-username/smartrails.git
   cd smartrails
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Run tests to ensure everything is working:
   ```bash
   bundle exec rspec
   ```

4. Create a new branch for your work:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Coding Standards

### Ruby Style Guide

We follow the Ruby community style guide with some modifications. Run RuboCop to check your code:

```bash
bundle exec rubocop
```

### Code Organization

- Keep files focused and single-purpose
- Use meaningful names for classes, methods, and variables
- Write self-documenting code with clear intent
- Add comments only when necessary to explain "why", not "what"

### Testing

- Write tests for all new functionality
- Follow the AAA pattern (Arrange, Act, Assert)
- Use descriptive test names that explain what is being tested
- Mock external dependencies appropriately
- Aim for fast, isolated unit tests

Example test structure:
```ruby
RSpec.describe SmartRails::Auditors::SecurityAuditor do
  describe '#check_csrf_protection' do
    context 'when CSRF protection is missing' do
      it 'adds a high severity issue' do
        # Arrange
        auditor = described_class.new(project_root)
        
        # Act
        auditor.run
        
        # Assert
        expect(auditor.issues).to include(
          a_hash_including(
            type: 'CSRF Protection',
            severity: :high
          )
        )
      end
    end
  end
end
```

### Documentation

- Update the README.md if you change functionality
- Add YARD documentation for public methods
- Include examples in your documentation
- Keep documentation up to date with code changes

### Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

## Creating New Auditors

If you're adding a new auditor:

1. Create a new file in `lib/smartrails/auditors/`
2. Extend `SmartRails::Auditors::BaseAuditor`
3. Implement the `#run` method
4. Add corresponding tests in `spec/smartrails/auditors/`
5. Update the audit command to include your auditor

Example:
```ruby
module SmartRails
  module Auditors
    class MyCustomAuditor < BaseAuditor
      def run
        # Your audit logic here
        check_something_important
        
        issues # Return the issues array
      end
      
      private
      
      def check_something_important
        # Check logic
        if problem_found?
          add_issue(
            type: 'Problem Type',
            message: 'Clear description of the problem',
            severity: :medium,
            file: 'path/to/problematic/file.rb',
            auto_fix: -> { fix_the_problem } # Optional
          )
        end
      end
    end
  end
end
```

## Release Process

Releases are handled by maintainers. The process is:

1. Update version number in `lib/smartrails/version.rb`
2. Update CHANGELOG.md
3. Commit changes: `git commit -m "Release version X.Y.Z"`
4. Create a git tag: `git tag vX.Y.Z`
5. Push changes: `git push origin main --tags`
6. Build and release gem: `rake release`

## Questions?

Feel free to open an issue with your question or reach out to the maintainers directly.

## Recognition

Contributors who submit accepted pull requests will be added to the AUTHORS file and recognized in the project documentation.

Thank you for contributing to SmartRails! 🚂