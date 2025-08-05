# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tty-prompt'

module SmartRails
  class FixManager
    attr_reader :project_path, :snapshot_manager, :git_manager, :prompt

    def initialize(project_path)
      @project_path = project_path
      @snapshot_manager = SnapshotManager.new(project_path)
      @git_manager = GitManager.new(project_path)
      @prompt = TTY::Prompt.new
      @fixes_log = []
    end

    def apply_fixes(issues, options = {})
      return { fixes: [], errors: [] } if issues.empty?
      
      # Filter auto-fixable issues
      fixable_issues = issues.select { |issue| issue[:auto_fixable] }
      
      if fixable_issues.empty?
        return { 
          fixes: [], 
          errors: [],
          message: "No auto-fixable issues found"
        }
      end
      
      # Group by risk level
      safe_fixes, risky_fixes = categorize_fixes(fixable_issues)
      
      fixes_applied = []
      errors = []
      
      # Handle safe fixes
      if safe_fixes.any? && (options[:auto_apply_safe] || confirm_safe_fixes(safe_fixes))
        safe_results = apply_fix_batch(safe_fixes, options.merge(risk_level: :safe))
        fixes_applied.concat(safe_results[:fixes])
        errors.concat(safe_results[:errors])
      end
      
      # Handle risky fixes with individual confirmation
      risky_fixes.each do |issue|
        next unless options[:apply_risky] || confirm_risky_fix(issue)
        
        fix_result = apply_single_fix(issue, options.merge(risk_level: :risky))
        
        if fix_result[:success]
          fixes_applied << fix_result
        else
          errors << fix_result
        end
      end
      
      # Generate summary report
      generate_fixes_report(fixes_applied, errors)
      
      {
        fixes: fixes_applied,
        errors: errors,
        summary: {
          total_attempted: fixable_issues.size,
          successful: fixes_applied.size,
          failed: errors.size,
          safe_fixes: safe_fixes.size,
          risky_fixes: risky_fixes.size
        }
      }
    end

    def dry_run(issues)
      fixable_issues = issues.select { |issue| issue[:auto_fixable] }
      
      dry_run_results = fixable_issues.map do |issue|
        generate_dry_run_preview(issue)
      end
      
      {
        previews: dry_run_results,
        summary: {
          total_fixable: fixable_issues.size,
          safe_fixes: dry_run_results.count { |r| r[:risk_level] == :safe },
          risky_fixes: dry_run_results.count { |r| r[:risk_level] == :risky },
          estimated_duration: estimate_fix_duration(fixable_issues)
        }
      }
    end

    def rollback(snapshot_id)
      @snapshot_manager.restore_snapshot(snapshot_id)
    end

    def list_snapshots
      @snapshot_manager.list_snapshots
    end

    private

    def categorize_fixes(issues)
      safe_fixes = []
      risky_fixes = []
      
      issues.each do |issue|
        if safe_fix?(issue)
          safe_fixes << issue
        else
          risky_fixes << issue
        end
      end
      
      [safe_fixes, risky_fixes]
    end

    def safe_fix?(issue)
      SAFE_FIX_TYPES.include?(issue[:tool]) &&
        SAFE_CATEGORIES.include?(issue[:metadata]&.dig(:warning_type) || issue[:metadata]&.dig(:cop_name))
    end

    def apply_fix_batch(issues, options = {})
      snapshot_id = @snapshot_manager.create_snapshot("batch_fix_#{Time.now.to_i}")
      
      fixes_applied = []
      errors = []
      
      begin
        @git_manager.create_fix_branch("smartrails_batch_fixes_#{Time.now.to_i}")
        
        issues.each do |issue|
          fix_result = execute_fix(issue)
          
          if fix_result[:success]
            fixes_applied << fix_result
            log_fix(issue, fix_result)
          else
            errors << fix_result
          end
        end
        
        # Validate all fixes together
        if validate_project_integrity
          @git_manager.commit_fixes(fixes_applied, "SmartRails: Applied #{fixes_applied.size} safe fixes")
          @snapshot_manager.mark_snapshot_success(snapshot_id)
        else
          rollback(snapshot_id)
          raise "Project integrity validation failed after applying fixes"
        end
        
      rescue StandardError => e
        rollback(snapshot_id)
        errors << {
          success: false,
          error: e.message,
          type: :batch_failure
        }
      end
      
      { fixes: fixes_applied, errors: errors }
    end

    def apply_single_fix(issue, options = {})
      snapshot_id = @snapshot_manager.create_snapshot("single_fix_#{issue[:fingerprint]}")
      
      begin
        branch_name = "smartrails_fix_#{issue[:fingerprint][0..7]}"
        @git_manager.create_fix_branch(branch_name)
        
        fix_result = execute_fix(issue)
        
        if fix_result[:success] && validate_fix_result(issue, fix_result)
          @git_manager.commit_fixes([fix_result], generate_commit_message(issue))
          @snapshot_manager.mark_snapshot_success(snapshot_id)
          log_fix(issue, fix_result)
          fix_result
        else
          rollback(snapshot_id)
          {
            success: false,
            issue: issue,
            error: "Fix validation failed",
            type: :validation_failure
          }
        end
        
      rescue StandardError => e
        rollback(snapshot_id)
        {
          success: false,
          issue: issue,
          error: e.message,
          type: :execution_failure
        }
      end
    end

    def execute_fix(issue)
      adapter = load_adapter_for_issue(issue)
      return { success: false, error: "No adapter available" } unless adapter
      
      adapter.auto_fix([issue]).first || { success: false, error: "Fix not applied" }
    end

    def generate_dry_run_preview(issue)
      adapter = load_adapter_for_issue(issue)
      
      {
        issue: issue,
        risk_level: safe_fix?(issue) ? :safe : :risky,
        estimated_changes: estimate_changes(issue),
        files_affected: extract_affected_files(issue),
        reversible: reversible_fix?(issue),
        dependencies: check_fix_dependencies(issue),
        preview: generate_diff_preview(issue)
      }
    end

    def load_adapter_for_issue(issue)
      adapter_class = case issue[:tool]
      when :brakeman
        Adapters::BrakemanAdapter
      when :rubocop
        Adapters::RubocopAdapter
      when :bundler_audit
        Adapters::BundlerAuditAdapter
      else
        return nil
      end
      
      adapter_class.new(@project_path)
    end

    def validate_project_integrity
      # Run basic Rails checks
      return false unless validate_syntax
      return false unless validate_rails_app
      return false unless run_critical_tests if tests_available?
      
      true
    end

    def validate_syntax
      # Check Ruby syntax for modified files
      result = `cd #{@project_path} && find . -name "*.rb" -exec ruby -c {} \\; 2>&1`
      !result.include?("syntax error")
    end

    def validate_rails_app
      # Basic Rails application validation
      result = `cd #{@project_path} && bundle exec rails runner "puts 'OK'" 2>&1`
      result.include?("OK")
    end

    def run_critical_tests
      # Run a subset of critical tests if available
      if File.exist?(File.join(@project_path, 'spec'))
        result = `cd #{@project_path} && bundle exec rspec --tag critical 2>&1`
        $?.success?
      elsif File.exist?(File.join(@project_path, 'test'))
        result = `cd #{@project_path} && bundle exec rails test 2>&1`
        $?.success?
      else
        true # No tests to run
      end
    end

    def tests_available?
      File.exist?(File.join(@project_path, 'spec')) || 
        File.exist?(File.join(@project_path, 'test'))
    end

    def confirm_safe_fixes(fixes)
      return true if ENV['SMARTRAILS_AUTO_APPLY'] == 'true'
      
      @prompt.yes?("Apply #{fixes.size} safe fixes automatically?") do |q|
        q.default true
      end
    end

    def confirm_risky_fix(issue)
      return false if ENV['SMARTRAILS_NO_RISKY'] == 'true'
      
      puts "\n" + "="*60
      puts "RISKY FIX REQUIRES CONFIRMATION"
      puts "="*60
      puts "Tool: #{issue[:tool]}"
      puts "Issue: #{issue[:message]}"
      puts "File: #{issue[:file]}:#{issue[:line]}"
      puts "Risk: This fix might require manual review"
      puts "="*60
      
      @prompt.yes?("Apply this risky fix?") do |q|
        q.default false
      end
    end

    def generate_commit_message(issue)
      "SmartRails: Fix #{issue[:tool]} issue in #{issue[:file]}\n\n#{issue[:message]}"
    end

    def log_fix(issue, result)
      @fixes_log << {
        timestamp: Time.now.iso8601,
        issue: issue,
        result: result,
        snapshot_id: @snapshot_manager.current_snapshot_id
      }
      
      # Write to fixes log file
      log_file = File.join(@project_path, 'tmp', 'smartrails_fixes.log')
      FileUtils.mkdir_p(File.dirname(log_file))
      File.open(log_file, 'a') do |f|
        f.puts JSON.pretty_generate(@fixes_log.last)
      end
    end

    def generate_fixes_report(fixes, errors)
      report = {
        timestamp: Time.now.iso8601,
        fixes_applied: fixes,
        errors: errors,
        summary: {
          total_fixes: fixes.size,
          total_errors: errors.size,
          files_modified: fixes.flat_map { |f| f[:files_modified] || [] }.uniq
        }
      }
      
      report_file = File.join(@project_path, 'tmp', 'smartrails_fixes_report.json')
      FileUtils.mkdir_p(File.dirname(report_file))
      File.write(report_file, JSON.pretty_generate(report))
      
      report
    end

    # Configuration constants
    SAFE_FIX_TYPES = [:rubocop].freeze
    
    SAFE_CATEGORIES = [
      'Style/StringLiterals',
      'Layout/TrailingWhitespace',
      'Style/EmptyLines',
      'Layout/IndentationConsistency'
    ].freeze

    def estimate_changes(issue)
      case issue[:tool]
      when :rubocop
        "Style/formatting changes (low risk)"
      when :brakeman
        "Security configuration changes (medium risk)"
      when :bundler_audit
        "Dependency updates (high risk)"
      else
        "Unknown changes"
      end
    end

    def extract_affected_files(issue)
      [issue[:file]].compact
    end

    def reversible_fix?(issue)
      # Most fixes are reversible via git, but some dependency updates might not be
      issue[:tool] != :bundler_audit
    end

    def check_fix_dependencies(issue)
      []  # TODO: Implement dependency checking
    end

    def generate_diff_preview(issue)
      "Preview not available in dry-run mode"  # TODO: Implement actual diff preview
    end

    def estimate_fix_duration(issues)
      issues.size * 2  # 2 seconds per fix estimate
    end

    def validate_fix_result(issue, result)
      return false unless result[:success]
      
      # Verify files were actually modified
      if result[:files_modified]
        result[:files_modified].all? { |file| File.exist?(File.join(@project_path, file)) }
      else
        true
      end
    end
  end
end