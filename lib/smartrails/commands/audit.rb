# frozen_string_literal: true

require_relative 'base'
require_relative '../auditors/security_auditor'
require_relative '../auditors/code_quality_auditor'
require_relative '../auditors/performance_auditor'
require_relative '../reporters/json_reporter'
require_relative '../reporters/html_reporter'

module SmartRails
  module Commands
    class Audit < Base
      def execute
        unless project_initialized?
          say "❌ Project not initialized. Run 'smartrails init PROJECT_NAME' first", :red
          return
        end

        say "🔍 Starting audit...\n", :yellow

        issues = []
        
        # Run all auditors
        auditors = [
          Auditors::SecurityAuditor,
          Auditors::CodeQualityAuditor,
          Auditors::PerformanceAuditor
        ]

        auditors.each do |auditor_class|
          auditor = auditor_class.new(project_root)
          say "Running #{auditor.name}...", :blue
          issues.concat(auditor.run)
        end

        # Process issues
        process_issues(issues)

        # Generate reports
        generate_reports(issues)

        say "\n✅ Audit completed!", :green
        say "📊 #{issues.count} issues found", issues.empty? ? :green : :yellow
      end

      private

      def process_issues(issues)
        return if issues.empty?

        issues.each do |issue|
          say "\n🚨 [#{issue[:severity].upcase}][#{issue[:type]}] #{issue[:message]}", severity_color(issue[:severity])
          
          if issue[:file]
            say "   📁 File: #{issue[:file]}#{issue[:line] ? ":#{issue[:line]}" : ''}", :white
          end

          if options[:auto] || options[:fix]
            if issue[:auto_fix]
              apply_fix(issue)
            else
              say "   ⚠️  No automatic fix available", :yellow
            end
          elsif !options[:auto] && issue[:auto_fix]
            response = ask("   Would you like to fix this issue? (y/N)", :yellow)
            apply_fix(issue) if response.downcase == 'y'
          end
        end
      end

      def apply_fix(issue)
        say "   🔧 Applying fix...", :blue
        begin
          issue[:auto_fix].call
          say "   ✅ Fix applied successfully", :green
        rescue => e
          say "   ❌ Failed to apply fix: #{e.message}", :red
        end
      end

      def generate_reports(issues)
        timestamp = Time.now
        
        # JSON report
        json_reporter = Reporters::JsonReporter.new
        json_file = reports_dir.join("audit_#{timestamp.to_i}.json")
        json_reporter.generate(issues, json_file)
        
        # HTML report
        if options[:format] == 'html' || !options[:auto]
          html_reporter = Reporters::HtmlReporter.new
          html_file = reports_dir.join("audit_#{timestamp.to_i}.html")
          html_reporter.generate(issues, html_file)
          
          # Also create a symlink to latest report
          latest_link = reports_dir.join('latest.html')
          FileUtils.rm_f(latest_link)
          FileUtils.ln_s(html_file.basename, latest_link)
          
          say "📄 HTML report: #{html_file}", :cyan
        end
        
        say "📊 JSON report: #{json_file}", :cyan
      end

      def severity_color(severity)
        case severity.to_s.downcase
        when 'critical', 'high' then :red
        when 'medium' then :yellow
        when 'low' then :blue
        else :white
        end
      end
    end
  end
end