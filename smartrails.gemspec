# frozen_string_literal: true

require_relative 'lib/smartrails/version'

Gem::Specification.new do |spec|
  spec.name          = 'smartrails'
  spec.version       = SmartRails::VERSION
  spec.authors       = ['SmartRails Team']
  spec.email         = ['contact@smartrails.dev']

  spec.summary       = 'Minimal auditing helper for Ruby on Rails projects'
  spec.description   = <<~DESC
    SmartRails offers a compact command-line interface that inspects a Rails project
    directory and reports basic findings. The gem is intentionally lightweight so it
    can serve as a foundation for richer audits.
  DESC
  spec.homepage      = 'https://github.com/smartrails/smartrails'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/smartrails/smartrails'
  spec.metadata['changelog_uri'] = 'https://github.com/smartrails/smartrails/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/smartrails/smartrails/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir        = 'bin'
  spec.executables   = ['smartrails']
  spec.require_paths = ['lib']
end
