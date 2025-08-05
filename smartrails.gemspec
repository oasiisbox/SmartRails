# frozen_string_literal: true

require_relative 'lib/smartrails/version'

Gem::Specification.new do |spec|
  spec.name          = 'smartrails'
  spec.version       = SmartRails::VERSION
  spec.authors       = ['SmartRails Team']
  spec.email         = ['contact@smartrails.dev']

  spec.summary       = 'Professional CLI tool for Rails project auditing, monitoring, and maintenance'
  spec.description   = <<~DESC
    SmartRails is a comprehensive CLI tool designed to help Ruby on Rails developers#{' '}
    audit, secure, and improve their applications. It provides automated security checks,#{' '}
    code quality analysis, performance auditing, and AI-powered suggestions for improvements.
  DESC
  spec.homepage      = 'https://github.com/smartrails/smartrails'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/smartrails/smartrails'
  spec.metadata['changelog_uri'] = 'https://github.com/smartrails/smartrails/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/smartrails/smartrails/issues'
  spec.metadata['documentation_uri'] = 'https://smartrails.dev/docs'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir        = 'bin'
  spec.executables   = ['smartrails']
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'bundler', '>= 1.17'
  spec.add_dependency 'colorize', '~> 0.8'
  spec.add_dependency 'thor', '~> 1.2'
  spec.add_dependency 'tty-progressbar', '~> 0.18'
  spec.add_dependency 'tty-prompt', '~> 0.23'
  spec.add_dependency 'tty-spinner', '~> 0.9'
  spec.add_dependency 'tty-table', '~> 0.12'

  # Optional dependencies for specific features - commented out for now
  # spec.add_development_dependency 'wkhtmltopdf-binary', '~> 0.12'

  spec.post_install_message = <<~MSG
    Thanks for installing SmartRails! 🚂

    Get started with:
      smartrails init my_project
      cd my_project
      smartrails audit

    For more information, visit: https://smartrails.dev
  MSG
end
