# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'tty-prompt'
require 'colorize'

require_relative 'base'
require_relative '../fix_manager'

module SmartRails
  module Commands
    class Fix < Base
      def initialize(options)
        super(options)
        @project_path = options[:project_path] || Dir.pwd
        @verbose = options[:verbose]
        @prompt = TTY::Prompt.new
      end

      def execute
        # Handle special commands first
        return list_snapshots if @options[:list_snapshots]
        return rollback_snapshot if @options[:rollback]

        puts "🔧 SmartRails Automatic Fixes".blue.bold
        puts "Safety Level: #{@options[:level]}".light_blue
        puts "=" * 50

        # Initialize fix manager
        fix_manager = FixManager.new(@project_path)
        
        # Load audit results
        issues = load_audit_results
        unless issues
          puts "❌ No audit results found. Run 'smartrails audit' first.".red
          return false
        end

        # Handle dry run
        if @options[:dry_run]
          return execute_dry_run(fix_manager, issues)
        end

        # Apply fixes
        execute_fixes(fix_manager, issues)
      end

      private

      def load_audit_results
        # Look for recent audit results
        reports_dir = File.join(@project_path, 'tmp', 'smartrails_reports')
        
        audit_files = [
          File.join(reports_dir, 'smartrails_audit.json'),
          File.join(reports_dir, 'audit_results.json')
        ]
        
        audit_file = audit_files.find { |f| File.exist?(f) }
        
        unless audit_file
          puts "🔍 No recent audit results found. Running quick audit...".yellow
          return run_quick_audit
        end

        begin
          audit_data = JSON.parse(File.read(audit_file), symbolize_names: true)
          extract_issues_from_audit(audit_data)
        rescue JSON::ParserError => e
          puts "❌ Failed to parse audit results: #{e.message}".red
          nil
        end
      end

      def run_quick_audit
        # Run a minimal audit to get issues for fixing
        require_relative '../orchestrator'
        
        orchestrator = Orchestrator.new(@project_path, { interactive: false })
        results = orchestrator.run
        
        extract_issues_from_audit(results)
      end

      def extract_issues_from_audit(audit_data)
        if audit_data[:phases]
          # New format from orchestrator
          audit_data[:phases].flat_map { |phase| phase[:issues] }
        elsif audit_data[:auditors]
          # Legacy format
          audit_data[:auditors].flat_map { |auditor| auditor[:findings] }
        else
          []
        end
      end

      def execute_dry_run(fix_manager, issues)
        puts "🔍 Dry Run - Previewing Changes".yellow.bold
        puts "=" * 50

        dry_run_results = fix_manager.dry_run(issues)
        
        if dry_run_results[:previews].empty?
          puts "✅ No auto-fixable issues found".green
          return true
        end

        puts "📋 Found #{dry_run_results[:previews].size} auto-fixable issues:\n"
        
        dry_run_results[:previews].each_with_index do |preview, index|
          issue = preview[:issue]
          puts "#{index + 1}. #{issue[:tool]} - #{issue[:message]}".bold
          puts "   File: #{issue[:file]}:#{issue[:line]}"
          puts "   Risk Level: #{preview[:risk_level]}".colorize(risk_color(preview[:risk_level]))
          puts "   Files Affected: #{preview[:files_affected].join(', ')}" if preview[:files_affected].any?
          puts "   Reversible: #{preview[:reversible] ? '✅' : '❌'}"
          puts ""
        end

        puts "📊 Summary:".bold
        puts "  Total fixable: #{dry_run_results[:summary][:total_fixable]}"
        puts "  Safe fixes: #{dry_run_results[:summary][:safe_fixes]}"
        puts "  Risky fixes: #{dry_run_results[:summary][:risky_fixes]}"
        puts "  Estimated duration: #{dry_run_results[:summary][:estimated_duration]}s"
        
        puts "\n💡 To apply fixes, run: smartrails fix --level #{@options[:level]}"
        
        true
      end

      def execute_fixes(fix_manager, issues)
        fixable_issues = issues.select { |issue| issue[:auto_fixable] }
        
        if fixable_issues.empty?
          puts "✅ No auto-fixable issues found".green
          return true
        end

        puts "🔍 Found #{fixable_issues.size} auto-fixable issues".blue
        puts ""

        # Apply fixes based on safety level
        fix_options = {
          auto_apply_safe: @options[:auto_apply_safe],
          apply_risky: @options[:level] != 'safe'
        }

        begin
          results = fix_manager.apply_fixes(fixable_issues, fix_options)
          
          display_fix_results(results)
          
          if results[:fixes].any?
            puts "✅ Applied #{results[:fixes].size} fixes successfully".green
            
            if results[:errors].any?
              puts "⚠️  #{results[:errors].size} fixes failed".yellow
            end
          else
            puts "ℹ️  No fixes were applied".blue
          end
          
          true
        rescue StandardError => e
          puts "❌ Fix application failed: #{e.message}".red
          puts e.backtrace.join("\n") if @verbose
          false
        end
      end

      def display_fix_results(results)
        puts "\n📊 Fix Results:".bold
        puts "=" * 30
        
        if results[:fixes].any?
          puts "✅ Successfully Applied:".green.bold
          results[:fixes].each do |fix|
            puts "  • #{fix[:description]}"
            if fix[:files_modified]
              puts "    Files: #{fix[:files_modified].join(', ')}"
            end
          end
          puts ""
        end
        
        if results[:errors].any?
          puts "❌ Failed to Apply:".red.bold
          results[:errors].each do |error|
            puts "  • #{error[:error] || error[:reason]}"
            puts "    Issue: #{error[:issue][:message]}" if error[:issue]
          end
          puts ""
        end
        
        puts "📈 Summary:".bold
        puts "  Total attempted: #{results[:summary][:total_attempted]}"
        puts "  Successful: #{results[:summary][:successful]}"
        puts "  Failed: #{results[:summary][:failed]}"
        puts "  Safe fixes: #{results[:summary][:safe_fixes]}"
        puts "  Risky fixes: #{results[:summary][:risky_fixes]}"
      end

      def list_snapshots
        puts "📸 Available Snapshots".blue.bold
        puts "=" * 50
        
        fix_manager = FixManager.new(@project_path)
        snapshots = fix_manager.list_snapshots
        
        if snapshots.empty?
          puts "No snapshots found."
          return true
        end
        
        snapshots.each_with_index do |snapshot, index|
          puts "#{index + 1}. #{snapshot[:id]}"
          puts "   Description: #{snapshot[:description]}"
          puts "   Created: #{snapshot[:timestamp]}"
          puts "   Files: #{snapshot[:file_count]}"
          puts "   Git Commit: #{snapshot[:git_commit][0..7]}" if snapshot[:git_commit]
          puts ""
        end
        
        puts "💡 To rollback to a snapshot: smartrails fix --rollback SNAPSHOT_ID"
        
        true
      end

      def rollback_snapshot
        snapshot_id = @options[:rollback]
        
        puts "🔄 Rolling back to snapshot: #{snapshot_id}".yellow.bold
        puts "=" * 50
        
        fix_manager = FixManager.new(@project_path)
        
        # Confirm rollback
        unless @options[:auto_apply_safe]
          confirmed = @prompt.yes?("This will restore files to their state at snapshot creation. Continue?") do |q|
            q.default false
          end
          
          return false unless confirmed
        end
        
        begin
          success = fix_manager.rollback(snapshot_id)
          
          if success
            puts "✅ Successfully rolled back to snapshot #{snapshot_id}".green
          else
            puts "❌ Failed to rollback to snapshot #{snapshot_id}".red
          end
          
          success
        rescue StandardError => e
          puts "❌ Rollback failed: #{e.message}".red
          puts e.backtrace.join("\n") if @verbose
          false
        end
      end

      def risk_color(risk_level)
        case risk_level
        when :safe then :green
        when :risky then :yellow
        else :red
        end
      end
    end
  end
end