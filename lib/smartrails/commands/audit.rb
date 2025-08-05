# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'tty-spinner'
require 'colorize'

require_relative 'base'
require_relative '../orchestrator'
require_relative '../reporters/unified_reporter'

module SmartRails
  module Commands
    class Audit < Base
      def initialize(options)
        super(options)
        @project_path = options[:project_path] || Dir.pwd
        @verbose = options[:verbose]
      end

      def execute
        puts "🔍 SmartRails Comprehensive Audit".blue.bold
        puts "Project: #{File.basename(@project_path)}".light_blue
        puts "=" * 50

        # Validate Rails project
        unless rails_project?
          puts "❌ Not a Rails project".red
          puts "Make sure you're in the root directory of a Rails application."
          return false
        end

        # Validate tools availability if in verbose mode
        if @verbose
          check_tools_availability
        end

        # Run the orchestrated audit
        begin
          audit_results = run_orchestrated_audit
          
          # Generate AI analysis if enabled
          if @options[:ai] && audit_results[:summary][:total_issues] > 0
            audit_results[:ai_analysis] = generate_ai_analysis(audit_results)
          end
          
          # Generate and save reports
          generate_reports(audit_results)
          
          # Display summary
          display_summary(audit_results)
          
          # Show recommendations
          show_recommendations(audit_results)
          
          # Prompt for fixes if issues found
          prompt_for_fixes(audit_results) if should_prompt_fixes?(audit_results)
          
          true
        rescue StandardError => e
          puts "❌ Audit failed: #{e.message}".red
          puts e.backtrace.join("\n") if @verbose
          false
        end
      end

      private

      def rails_project?
        File.exist?(File.join(@project_path, 'config', 'application.rb')) &&
          (File.exist?(File.join(@project_path, 'Gemfile')) || 
           File.exist?(File.join(@project_path, 'gems.rb')))
      end

      def check_tools_availability
        puts "🔧 Checking tool availability...".yellow
        
        tools_status = {
          'Brakeman' => gem_available?('brakeman'),
          'RuboCop' => gem_available?('rubocop'),
          'bundler-audit' => command_available?('bundle-audit'),
          'Rails Best Practices' => gem_available?('rails_best_practices'),
          'RubyCritic' => gem_available?('rubycritic')
        }
        
        tools_status.each do |tool, available|
          status = available ? "✅" : "⚠️"
          puts "  #{status} #{tool}"
        end
        
        puts ""
      end

      def run_orchestrated_audit
        spinner = TTY::Spinner.new("[:spinner] Initializing audit orchestrator...", format: :dots)
        spinner.auto_spin
        
        # Create orchestrator with options
        orchestrator_options = {
          only: @options[:only],
          skip: @options[:skip],
          interactive: @options[:interactive],
          verbose: @verbose
        }
        
        orchestrator = Orchestrator.new(@project_path, orchestrator_options)
        spinner.success("(initialized)")
        
        # Run the audit
        puts "\n🚀 Running audit phases...".blue
        results = orchestrator.run
        
        puts "\n✅ Audit completed in #{results[:duration_ms]}ms".green
        results
      end

      def generate_ai_analysis(audit_results)
        return nil unless ai_available?
        
        spinner = TTY::Spinner.new("[:spinner] Generating AI analysis...", format: :dots)
        spinner.auto_spin
        
        begin
          # For now, create a simple analysis
          # In full implementation, this would use SmartRailsAgent
          analysis = create_basic_analysis(audit_results)
          spinner.success("(completed)")
          analysis
        rescue StandardError => e
          spinner.error("(failed: #{e.message})")
          nil
        end
      end

      def create_basic_analysis(audit_results)
        summary = audit_results[:summary]
        
        recommendations = {
          immediate: [],
          short_term: [],
          long_term: []
        }
        
        # Generate basic recommendations
        if summary[:critical] > 0
          recommendations[:immediate] << "Address #{summary[:critical]} critical security issues immediately"
        end
        
        if summary[:auto_fixable] > 0
          recommendations[:immediate] << "Apply #{summary[:auto_fixable]} automatic fixes using 'smartrails fix --level safe'"
        end
        
        if summary[:high] > 5
          recommendations[:short_term] << "Prioritize fixing #{summary[:high]} high-severity issues"
        end
        
        if audit_results[:score][:global] < 70
          recommendations[:long_term] << "Establish code quality processes and continuous monitoring"
        end
        
        {
          summary: "Found #{summary[:total_issues]} issues with #{summary[:auto_fixable]} auto-fixable items",
          recommendations: recommendations,
          priority_matrix: generate_priority_matrix(audit_results)
        }
      end

      def generate_priority_matrix(audit_results)
        all_issues = audit_results[:phases].flat_map { |p| p[:issues] }
        
        {
          critical_security: all_issues.count { |i| i[:severity] == :critical && i[:category] == :security },
          high_performance: all_issues.count { |i| i[:severity] == :high && i[:category] == :performance },
          auto_fixable_total: all_issues.count { |i| i[:auto_fixable] }
        }
      end

      def generate_reports(audit_results)
        puts "\n📊 Generating reports...".blue
        
        # Determine output directory
        output_dir = @options[:output] || File.join(@project_path, 'tmp', 'smartrails_reports')
        FileUtils.mkdir_p(output_dir)
        
        # Generate reports
        reporter = Reporters::UnifiedReporter.new(
          audit_results, 
          formats: @options[:format],
          output_dir: output_dir
        )
        
        reports = reporter.generate_reports
        
        # Display generated reports
        reports.each do |format, _content|
          filename = get_report_filename(format)
          file_path = File.join(output_dir, filename)
          puts "  📄 #{format.to_s.upcase} report: #{file_path}".light_blue
        end
        
        reports
      end

      def display_summary(results)
        puts "\n" + "=" * 50
        puts "📈 AUDIT SUMMARY".blue.bold
        puts "=" * 50
        
        summary = results[:summary]
        scores = results[:score]
        
        # Overall score
        score_color = case scores[:global]
                     when 90..100 then :green
                     when 70..89 then :yellow
                     when 50..69 then :red
                     else :light_red
                     end
        
        puts "🎯 Global Score: #{scores[:global]}%".colorize(score_color).bold
        puts ""
        
        # Issues breakdown
        puts "📊 Issues Found:"
        puts "  🚨 Critical: #{summary[:critical]}".red if summary[:critical] > 0
        puts "  🔴 High: #{summary[:high]}".light_red if summary[:high] > 0
        puts "  🟡 Medium: #{summary[:medium]}".yellow if summary[:medium] > 0
        puts "  ⚪ Low: #{summary[:low]}".light_black if summary[:low] > 0
        puts "  ✅ Auto-fixable: #{summary[:auto_fixable]}".green if summary[:auto_fixable] > 0
        puts ""
        
        # Category scores
        puts "📋 Category Scores:"
        scores.each do |category, score|
          next if category == :global
          
          color = score >= 80 ? :green : score >= 60 ? :yellow : :red
          puts "  #{category.to_s.capitalize}: #{score}%".colorize(color)
        end
        
        # Tools summary
        puts "\n🔧 Tools Summary:"
        puts "  Available: #{summary[:tools_available]}"
        puts "  Executed: #{summary[:tools_run]}"
        puts "  Duration: #{results[:duration_ms]}ms"
      end

      def show_recommendations(results)
        return unless results[:ai_analysis] || results[:summary][:total_issues] > 0
        
        puts "\n" + "=" * 50
        puts "💡 RECOMMENDATIONS".yellow.bold
        puts "=" * 50
        
        if results[:ai_analysis] && results[:ai_analysis][:recommendations]
          # AI-generated recommendations
          recommendations = results[:ai_analysis][:recommendations]
          
          if recommendations[:immediate]&.any?
            puts "🚨 Immediate Actions:".red.bold
            recommendations[:immediate].each { |rec| puts "  • #{rec}" }
            puts ""
          end
          
          if recommendations[:short_term]&.any?
            puts "📅 Short Term:".yellow.bold
            recommendations[:short_term].each { |rec| puts "  • #{rec}" }
            puts ""
          end
          
          if recommendations[:long_term]&.any?
            puts "🎯 Long Term:".blue.bold
            recommendations[:long_term].each { |rec| puts "  • #{rec}" }
            puts ""
          end
        else
          # Basic recommendations
          summary = results[:summary]
          
          if summary[:critical] > 0
            puts "🚨 Critical: Address #{summary[:critical]} critical issues immediately".red.bold
          end
          
          if summary[:auto_fixable] > 0
            puts "⚡ Quick Win: Run 'smartrails fix --level safe' to apply #{summary[:auto_fixable]} automatic fixes".green
          end
          
          if summary[:high] > 3
            puts "📋 Priority: Focus on #{summary[:high]} high-priority issues".yellow
          end
        end
      end

      def prompt_for_fixes(results)
        return unless @options[:interactive]
        return unless results[:summary][:auto_fixable] > 0
        
        puts "\n" + "=" * 50
        puts "🔧 AUTOMATIC FIXES AVAILABLE".green.bold
        puts "=" * 50
        
        puts "#{results[:summary][:auto_fixable]} issues can be automatically fixed."
        puts ""
        puts "Options:"
        puts "  1. Apply safe fixes only (recommended)"
        puts "  2. Review and apply all fixes interactively"
        puts "  3. Generate dry-run preview"
        puts "  4. Skip for now"
        
        print "\nChoose an option (1-4): "
        choice = STDIN.gets.chomp
        
        case choice
        when '1'
          system("smartrails fix --level safe --auto-apply-safe")
        when '2'
          system("smartrails fix --level risky")
        when '3'
          system("smartrails fix --dry-run")
        else
          puts "Skipped. Run 'smartrails fix' later to apply fixes."
        end
      end

      def should_prompt_fixes?(results)
        results[:summary][:auto_fixable] > 0 && 
          @options[:interactive] && 
          !@options[:format].include?('ci')
      end

      def get_report_filename(format)
        case format
        when :json then 'smartrails_audit.json'
        when :html then 'smartrails_report.html'
        when :markdown then 'smartrails_report.md'
        when :ci then 'smartrails_ci.json'
        when :sarif then 'smartrails.sarif'
        when :badge then 'smartrails_badge.json'
        else "smartrails_report.#{format}"
        end
      end

      # Helper methods
      def gem_available?(gem_name)
        Gem::Specification.find_by_name(gem_name)
        true
      rescue Gem::LoadError
        false
      end

      def command_available?(command)
        system("which #{command} > /dev/null 2>&1")
      end

      def ai_available?
        @options[:ai] && (
          ENV['OPENAI_API_KEY'] || 
          ENV['ANTHROPIC_API_KEY'] || 
          command_available?('ollama')
        )
      end
    end
  end
end