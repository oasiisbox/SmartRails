# frozen_string_literal: true

require_relative 'smartrails/version'
require_relative 'smartrails/cli'

# Core components
require_relative 'smartrails/auditors/base_auditor'
require_relative 'smartrails/auditors/security_auditor'
require_relative 'smartrails/auditors/performance_auditor'
require_relative 'smartrails/auditors/code_quality_auditor'

# Adapters
require_relative 'smartrails/adapters/base_adapter'
require_relative 'smartrails/adapters/brakeman_adapter'
require_relative 'smartrails/adapters/bundler_audit_adapter'
require_relative 'smartrails/adapters/rubocop_adapter'

# Managers
require_relative 'smartrails/fix_manager'
require_relative 'smartrails/git_manager'
require_relative 'smartrails/orchestrator'

module SmartRails
  class Error < StandardError; end

  class << self
    def root
      @root ||= Pathname.new(File.expand_path('..', __dir__))
    end
  end
end
