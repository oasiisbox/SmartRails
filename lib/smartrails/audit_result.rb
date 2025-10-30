# frozen_string_literal: true

require 'pathname'

module SmartRails
  # Represents the outcome of a SmartRails audit.
  # Stores basic metadata about the project and a list of findings that can be
  # expanded by future auditors.
  class AuditResult
    Finding = Struct.new(:category, :message, :details, keyword_init: true)

    attr_reader :project_path, :findings

    def initialize(project_path:, findings: [])
      @project_path = Pathname.new(project_path)
      @findings = findings.dup
    end

    def add_issue(category, message, details: nil)
      findings << Finding.new(category: category, message: message, details: details)
    end

    def ok?
      findings.empty?
    end
  end
end
