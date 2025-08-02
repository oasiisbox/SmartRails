# frozen_string_literal: true

require 'json'

module SmartRails
  module Reporters
    class JsonReporter
      def generate(issues, output_file)
        report = {
          timestamp: Time.now.iso8601,
          version: SmartRails::VERSION,
          summary: generate_summary(issues),
          statistics: generate_statistics(issues),
          issues: issues.map { |issue| format_issue(issue) }
        }

        File.write(output_file, JSON.pretty_generate(report))
      end

      private

      def generate_summary(issues)
        return 'No issues found. Your Rails application looks good!' if issues.empty?

        critical_count = issues.count { |i| i[:severity] == :critical }
        high_count = issues.count { |i| i[:severity] == :high }

        if critical_count > 0
          "Found #{critical_count} critical and #{high_count} high severity issues that need immediate attention."
        elsif high_count > 0
          "Found #{high_count} high severity issues that should be addressed soon."
        else
          "Found #{issues.count} issues. Most are minor and can be addressed over time."
        end
      end

      def generate_statistics(issues)
        {
          total: issues.count,
          by_severity: {
            critical: issues.count { |i| i[:severity] == :critical },
            high: issues.count { |i| i[:severity] == :high },
            medium: issues.count { |i| i[:severity] == :medium },
            low: issues.count { |i| i[:severity] == :low }
          },
          by_type: issues.group_by { |i| i[:type] }
            .transform_values(&:count),
          by_auditor: issues.group_by { |i| i[:auditor] }
            .transform_values(&:count),
          auto_fixable: issues.count { |i| i[:auto_fix] }
        }
      end

      def format_issue(issue)
        {
          type: issue[:type],
          message: issue[:message],
          severity: issue[:severity],
          file: issue[:file],
          line: issue[:line],
          auditor: issue[:auditor],
          auto_fixable: !issue[:auto_fix].nil?
        }
      end
    end
  end
end
