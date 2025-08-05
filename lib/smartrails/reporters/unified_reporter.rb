# frozen_string_literal: true

require 'json'
require 'erb'
require 'fileutils'

module SmartRails
  module Reporters
    class UnifiedReporter
      attr_reader :audit_results, :options

      def initialize(audit_results, options = {})
        @audit_results = audit_results
        @options = options
      end

      def generate_reports
        reports = {}
        
        # Generate each requested format
        formats = @options[:formats] || [:json, :html]
        
        formats.each do |format|
          case format
          when :json
            reports[:json] = generate_json_report
          when :html
            reports[:html] = generate_html_report
          when :markdown
            reports[:markdown] = generate_markdown_report
          when :badge
            reports[:badge] = generate_badge_report
          when :ci
            reports[:ci] = generate_ci_report
          when :sarif
            reports[:sarif] = generate_sarif_report
          end
        end
        
        # Save reports to files if output directory specified
        if @options[:output_dir]
          save_reports_to_files(reports)
        end
        
        reports
      end

      private

      def generate_json_report
        report = {
          smartrails: {
            version: SmartRails::VERSION,
            report_format: 'unified',
            generated_at: Time.now.iso8601
          },
          metadata: @audit_results[:metadata],
          summary: @audit_results[:summary],
          scores: @audit_results[:score],
          phases: @audit_results[:phases],
          recommendations: generate_recommendations,
          ai_analysis: @audit_results[:ai_analysis]
        }
        
        JSON.pretty_generate(report)
      end

      def generate_html_report
        template_path = File.join(__dir__, 'templates', 'unified_report.html.erb')
        template = File.read(template_path)
        
        erb = ERB.new(template)
        
        # Prepare template variables
        @title = "SmartRails Audit Report - #{@audit_results[:metadata][:project]}"
        @generated_at = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        @total_issues = @audit_results[:summary][:total_issues]
        @global_score = @audit_results[:score][:global]
        @phases = @audit_results[:phases]
        @recommendations = generate_recommendations
        
        erb.result(binding)
      end

      def generate_markdown_report
        md = []
        
        # Header
        md << "# 📊 SmartRails Audit Report"
        md << ""
        md << "**Project**: #{@audit_results[:metadata][:project]}"
        md << "**Generated**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
        md << "**SmartRails Version**: #{SmartRails::VERSION}"
        md << ""
        
        # Badge
        badge = generate_badge_markdown
        md << badge if badge
        md << ""
        
        # Summary
        md << "## 📈 Summary"
        md << ""
        summary = @audit_results[:summary]
        md << "- **Total Issues**: #{summary[:total_issues]}"
        md << "- **Critical**: #{summary[:critical]} 🔴"
        md << "- **High**: #{summary[:high]} 🟠"
        md << "- **Medium**: #{summary[:medium]} 🟡"
        md << "- **Low**: #{summary[:low]} ⚪"
        md << "- **Auto-fixable**: #{summary[:auto_fixable]} ✅"
        md << ""
        
        # Scores
        md << "## 🎯 Scores"
        md << ""
        scores = @audit_results[:score]
        md << "| Category | Score | Status |"
        md << "|----------|-------|--------|"
        md << "| **Global** | #{scores[:global]}% | #{score_status(scores[:global])} |"
        md << "| Security | #{scores[:security]}% | #{score_status(scores[:security])} |"
        md << "| Quality | #{scores[:quality]}% | #{score_status(scores[:quality])} |"
        md << "| Performance | #{scores[:performance]}% | #{score_status(scores[:performance])} |"
        md << "| Database | #{scores[:database]}% | #{score_status(scores[:database])} |"
        md << ""
        
        # Phase Results
        md << "## 🔍 Audit Phases"
        md << ""
        
        @audit_results[:phases].each do |phase|
          md << "### #{phase[:name]}"
          md << ""
          md << "**Duration**: #{phase[:duration_ms]}ms"
          md << "**Tools**: #{phase[:tools_run].join(', ')}"
          md << "**Issues Found**: #{phase[:issue_count]}"
          md << ""
          
          if phase[:issues].any?
            # Group issues by severity
            issues_by_severity = phase[:issues].group_by { |i| i[:severity] }
            
            [:critical, :high, :medium, :low].each do |severity|
              next unless issues_by_severity[severity]
              
              md << "#### #{severity.to_s.capitalize} Issues (#{issues_by_severity[severity].size})"
              md << ""
              
              issues_by_severity[severity].first(5).each do |issue|
                icon = severity_icon(issue[:severity])
                md << "- #{icon} **#{issue[:file]}:#{issue[:line]}** - #{issue[:message]}"
                md << "  - Tool: `#{issue[:tool]}`"
                md << "  - Auto-fixable: #{issue[:auto_fixable] ? '✅' : '❌'}"
                md << ""
              end
              
              if issues_by_severity[severity].size > 5
                md << "*...and #{issues_by_severity[severity].size - 5} more*"
                md << ""
              end
            end
          end
        end
        
        # Recommendations
        recommendations = generate_recommendations
        if recommendations.any?
          md << "## 💡 Recommendations"
          md << ""
          
          [:immediate, :short_term, :long_term].each do |timeframe|
            next unless recommendations[timeframe]&.any?
            
            md << "### #{timeframe.to_s.humanize}"
            md << ""
            
            recommendations[timeframe].each do |rec|
              md << "- #{rec}"
            end
            md << ""
          end
        end
        
        # Footer
        md << "---"
        md << "*Report generated by [SmartRails](https://github.com/oasiisbox/SmartRails)*"
        
        md.join("\n")
      end

      def generate_badge_report
        score = @audit_results[:score][:global]
        level = determine_badge_level(score)
        
        {
          level: level,
          score: score,
          color: badge_color(level),
          markdown: generate_badge_markdown,
          html: generate_badge_html,
          svg_url: generate_badge_svg_url(level, score),
          shield_url: generate_shield_url(level, score)
        }
      end

      def generate_ci_report
        # Format suitable for CI/CD systems
        {
          format: 'smartrails-ci',
          version: '1.0',
          timestamp: Time.now.iso8601,
          project: @audit_results[:metadata][:project],
          status: determine_ci_status,
          summary: {
            total_issues: @audit_results[:summary][:total_issues],
            critical_issues: @audit_results[:summary][:critical],
            high_issues: @audit_results[:summary][:high],
            auto_fixable: @audit_results[:summary][:auto_fixable],
            global_score: @audit_results[:score][:global]
          },
          phases: @audit_results[:phases].map do |phase|
            {
              name: phase[:name],
              duration_ms: phase[:duration_ms],
              issues: phase[:issue_count],
              status: phase[:issue_count] == 0 ? 'pass' : 'fail'
            }
          end,
          recommendations: generate_ci_recommendations
        }
      end

      def generate_sarif_report
        # SARIF 2.1.0 format for security tools integration
        {
          '$schema': 'https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json',
          version: '2.1.0',
          runs: [
            {
              tool: {
                driver: {
                  name: 'SmartRails',
                  version: SmartRails::VERSION,
                  informationUri: 'https://github.com/oasiisbox/SmartRails',
                  rules: generate_sarif_rules
                }
              },
              results: generate_sarif_results
            }
          ]
        }
      end

      def generate_recommendations
        all_issues = @audit_results[:phases].flat_map { |p| p[:issues] }
        
        immediate = []
        short_term = []
        long_term = []
        
        # Critical and high severity issues need immediate attention
        critical_high = all_issues.select { |i| [:critical, :high].include?(i[:severity]) }
        if critical_high.any?
          immediate << "Address #{critical_high.size} critical/high severity issues immediately"
          immediate << "Focus on security issues first, then performance problems"
        end
        
        # Auto-fixable issues are quick wins
        auto_fixable = all_issues.select { |i| i[:auto_fixable] }
        if auto_fixable.any?
          immediate << "Apply #{auto_fixable.size} automatic fixes with `smartrails fix --safe`"
        end
        
        # Tool-specific recommendations
        tools_with_issues = @audit_results[:phases].map { |p| p[:tools_run] }.flatten.uniq
        
        if tools_with_issues.include?(:brakeman)
          short_term << "Review and update .brakeman.ignore file"
          short_term << "Consider implementing Content Security Policy"
        end
        
        if tools_with_issues.include?(:rubocop)
          short_term << "Update RuboCop configuration for consistency"
          short_term << "Set up pre-commit hooks for code quality"
        end
        
        if tools_with_issues.include?(:bundler_audit)
          immediate << "Update vulnerable gems immediately"
          short_term << "Set up automated dependency monitoring"
        end
        
        # Long-term improvements
        if @audit_results[:score][:global] < 80
          long_term << "Establish code quality metrics and monitoring"
          long_term << "Implement continuous security scanning in CI/CD"
          long_term << "Consider adopting additional Rails security best practices"
        end
        
        {
          immediate: immediate,
          short_term: short_term,
          long_term: long_term
        }
      end

      def generate_ci_recommendations
        recommendations = generate_recommendations
        recommendations[:immediate] + recommendations[:short_term]
      end

      def generate_sarif_rules
        # Extract unique rule types from all issues
        all_issues = @audit_results[:phases].flat_map { |p| p[:issues] }
        
        all_issues.group_by { |i| "#{i[:tool]}_#{i[:metadata]&.dig(:cop_name) || i[:metadata]&.dig(:warning_type) || 'general'}" }
                  .map do |rule_id, issues|
          first_issue = issues.first
          {
            id: rule_id,
            name: first_issue[:message]&.split(':')&.first || rule_id,
            shortDescription: {
              text: first_issue[:message]&.split(':')&.first || 'SmartRails issue'
            },
            helpUri: first_issue[:documentation_url]
          }
        end
      end

      def generate_sarif_results
        all_issues = @audit_results[:phases].flat_map { |p| p[:issues] }
        
        all_issues.map do |issue|
          rule_id = "#{issue[:tool]}_#{issue[:metadata]&.dig(:cop_name) || issue[:metadata]&.dig(:warning_type) || 'general'}"
          
          {
            ruleId: rule_id,
            message: {
              text: issue[:message]
            },
            locations: [
              {
                physicalLocation: {
                  artifactLocation: {
                    uri: issue[:file]
                  },
                  region: {
                    startLine: issue[:line] || 1,
                    startColumn: issue[:column] || 1
                  }
                }
              }
            ],
            level: sarif_level(issue[:severity])
          }
        end
      end

      def save_reports_to_files(reports)
        FileUtils.mkdir_p(@options[:output_dir])
        
        reports.each do |format, content|
          filename = case format
                    when :json
                      'smartrails_report.json'
                    when :html
                      'smartrails_report.html'
                    when :markdown
                      'smartrails_report.md'
                    when :ci
                      'smartrails_ci.json'
                    when :sarif
                      'smartrails.sarif'
                    when :badge
                      'smartrails_badge.json'
                    else
                      "smartrails_report.#{format}"
                    end
          
          file_path = File.join(@options[:output_dir], filename)
          
          if content.is_a?(Hash) || content.is_a?(Array)
            File.write(file_path, JSON.pretty_generate(content))
          else
            File.write(file_path, content)
          end
          
          Rails.logger.info "Report saved: #{file_path}" if defined?(Rails)
        end
      end

      # Helper methods
      def determine_badge_level(score)
        case score
        when 95..100 then :platinum
        when 85..94 then :gold
        when 75..84 then :silver
        when 65..74 then :bronze
        when 50..64 then :certified
        else :none
        end
      end

      def badge_color(level)
        {
          platinum: '#e5e4e2',
          gold: '#ffd700',
          silver: '#c0c0c0',
          bronze: '#cd7f32',
          certified: '#4c9aff',
          none: '#red'
        }[level]
      end

      def generate_badge_markdown
        badge = generate_badge_report
        return nil if badge[:level] == :none
        
        "[![SmartRails #{badge[:level].to_s.capitalize}](#{badge[:shield_url]})](https://github.com/oasiisbox/SmartRails)"
      end

      def generate_badge_html
        badge = generate_badge_report
        return nil if badge[:level] == :none
        
        "<a href='https://github.com/oasiisbox/SmartRails'><img src='#{badge[:shield_url]}' alt='SmartRails #{badge[:level].to_s.capitalize}' /></a>"
      end

      def generate_shield_url(level, score)
        "https://img.shields.io/badge/SmartRails-#{level}%20#{score}%25-#{badge_color(level)[1..-1]}.svg"
      end

      def generate_badge_svg_url(level, score)
        # This would be a custom SVG endpoint in SmartRailsWeb
        "https://smartrails.io/badge/#{level}/#{score}.svg"
      end

      def score_status(score)
        case score
        when 90..100 then '🟢 Excellent'
        when 80..89 then '🟡 Good'
        when 70..79 then '🟠 Fair'
        when 60..69 then '🔴 Poor'
        else '💀 Critical'
        end
      end

      def severity_icon(severity)
        {
          critical: '🚨',
          high: '🔴',
          medium: '🟡',
          low: '⚪'
        }[severity] || '❓'
      end

      def determine_ci_status
        critical = @audit_results[:summary][:critical] || 0
        high = @audit_results[:summary][:high] || 0
        
        if critical > 0
          'failure'
        elsif high > 3
          'warning'
        else
          'success'
        end
      end

      def sarif_level(severity)
        case severity
        when :critical then 'error'
        when :high then 'error'
        when :medium then 'warning'
        when :low then 'note'
        else 'note'
        end
      end
    end
  end
end