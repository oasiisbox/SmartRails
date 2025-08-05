# frozen_string_literal: true

require 'thor'
require 'json'
require 'fileutils'
require 'pathname'
require 'tty-prompt'
require 'colorize'

require_relative 'commands/init'
require_relative 'commands/audit'
require_relative 'commands/suggest'
require_relative 'commands/fix'
require_relative 'commands/badge'
# require_relative 'commands/report' # TODO: Implement report command
require_relative 'version'

module SmartRails
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    # Global options
    class_option :verbose, aliases: '-v', type: :boolean, default: false, desc: 'Enable verbose output'
    class_option :config, aliases: '-c', type: :string, desc: 'Path to configuration file'
    class_option :project_path, aliases: '-p', type: :string, desc: 'Path to Rails project', default: '.'

    desc 'version', 'Display SmartRails version'
    def version
      say "SmartRails v#{SmartRails::VERSION}".blue
      say "Ruby #{RUBY_VERSION} on #{RUBY_PLATFORM}"
      say "The comprehensive Rails audit and security tool"
    end

    desc 'init [PROJECT_NAME]', 'Initialize SmartRails in a Rails project'
    option :force, type: :boolean, default: false, desc: 'Overwrite existing configuration'
    def init(project_name = nil)
      Commands::Init.new(options.merge(global_options)).execute(project_name)
    end

    desc 'audit', 'Run comprehensive audit of the Rails project'
    long_desc <<-LONGDESC
      Run a comprehensive audit of your Rails project using multiple tools:
      - Security analysis (Brakeman, bundler-audit)
      - Code quality (RuboCop, Rails Best Practices)
      - Database health (ActiveRecord Doctor)
      - Performance checks (Bullet, memory profiler)
      - Dead code detection (Traceroute, Debride)

      Use --only to run specific phases or --skip to exclude phases.
      Use --format to specify output format (json, html, markdown, ci, sarif).
    LONGDESC
    option :only, type: :array, desc: 'Run only specific phases (security, quality, database, performance, cleanup)'
    option :skip, type: :array, desc: 'Skip specific phases'
    option :format, type: :array, default: ['json'], desc: 'Output formats (json, html, markdown, badge, ci, sarif)'
    option :output, aliases: '-o', type: :string, desc: 'Output directory for reports'
    option :ai, type: :boolean, default: true, desc: 'Enable AI analysis and recommendations'
    option :interactive, aliases: '-i', type: :boolean, default: true, desc: 'Interactive mode with confirmations'
    def audit
      Commands::Audit.new(options.merge(global_options)).execute
    end

    desc 'fix', 'Apply automatic fixes to detected issues'
    long_desc <<-LONGDESC
      Apply automatic fixes to issues found during audit.
      
      Safety levels:
      - safe: Apply only safe, non-breaking fixes automatically
      - risky: Apply all fixes with confirmation prompts
      - all: Apply all auto-fixable issues (dangerous!)

      Always creates snapshots and git branches for rollback safety.
    LONGDESC
    option :level, type: :string, default: 'safe', desc: 'Safety level (safe, risky, all)'
    option :dry_run, type: :boolean, default: false, desc: 'Preview changes without applying'
    option :rollback, type: :string, desc: 'Rollback to specific snapshot ID'
    option :list_snapshots, type: :boolean, default: false, desc: 'List available snapshots'
    option :auto_apply_safe, type: :boolean, default: false, desc: 'Auto-apply safe fixes without confirmation'
    def fix
      Commands::Fix.new(options.merge(global_options)).execute
    end

    desc 'suggest [SOURCE]', 'Get AI-powered suggestions and analysis'
    long_desc <<-LONGDESC
      Use AI to analyze code, audit results, or specific questions.
      
      Examples:
        smartrails suggest --file app/models/user.rb
        smartrails suggest "How to improve security in Rails?"
        smartrails suggest --audit-results tmp/audit.json
    LONGDESC
    option :file, aliases: '-f', type: :string, desc: 'Path to file to analyze'
    option :audit_results, aliases: '-a', type: :string, desc: 'Path to audit results JSON file'
    option :llm, aliases: '-l', type: :string, default: 'ollama', desc: 'LLM provider (ollama, openai, claude, mistral)'
    option :model, aliases: '-m', type: :string, desc: 'Specific model name to use'
    option :stream, type: :boolean, default: true, desc: 'Stream response in real-time'
    def suggest(source = nil)
      Commands::Suggest.new(options.merge(global_options)).execute(source)
    end

    desc 'badge', 'Generate and manage SmartRails quality badges'
    long_desc <<-LONGDESC
      Generate quality badges for your project based on audit results.
      
      Badge levels: Platinum (95%+), Gold (85%+), Silver (75%+), Bronze (65%+), Certified (50%+)
    LONGDESC
    option :update_readme, type: :boolean, default: false, desc: 'Automatically update README with badge'
    option :format, type: :string, default: 'markdown', desc: 'Badge format (markdown, html, svg)'
    option :audit_file, type: :string, desc: 'Path to audit results file'
    def badge
      Commands::Badge.new(options.merge(global_options)).execute
    end

    # TODO: Implement report command
    # desc 'report', 'Generate detailed reports from audit results'
    # option :input, aliases: '-i', type: :string, required: true, desc: 'Input audit results file'
    # option :format, type: :array, default: ['html'], desc: 'Output formats'
    # option :output, aliases: '-o', type: :string, desc: 'Output directory'
    # option :open, type: :boolean, default: false, desc: 'Open report in browser'
    # def report
    #   Commands::Report.new(options.merge(global_options)).execute
    # end

    # TODO: Implement check and config commands
    # desc 'check', 'Check system requirements and tool availability'
    # option :tools, type: :boolean, default: false, desc: 'Check available audit tools'
    # option :ai, type: :boolean, default: false, desc: 'Check AI/LLM connectivity'
    # option :all, type: :boolean, default: false, desc: 'Check everything'
    # def check
    #   Commands::Check.new(options.merge(global_options)).execute
    # end

    # desc 'config', 'Manage SmartRails configuration'
    # option :show, type: :boolean, default: false, desc: 'Show current configuration'
    # option :reset, type: :boolean, default: false, desc: 'Reset to default configuration'
    # option :set, type: :hash, desc: 'Set configuration values (key:value)'
    # def config
    #   Commands::Config.new(options.merge(global_options)).execute
    # end

    # TODO: Implement advanced subcommands
    # desc 'ci', 'CI/CD integration commands'
    # subcommand 'ci', Commands::CI

    # desc 'web', 'Web interface commands'
    # subcommand 'web', Commands::Web

    # TODO: Legacy aliases for backward compatibility
    # desc 'check:llm', 'Check LLM connection (legacy alias)'
    # def check_llm
    #   invoke :check, [], { ai: true }
    # end

    # Hidden development commands
    private

    desc 'dev:test_orchestrator', 'Test the audit orchestrator', hide: true
    def dev_test_orchestrator
      require_relative 'orchestrator'
      
      orchestrator = Orchestrator.new(options[:project_path] || '.', options)
      results = orchestrator.run
      
      puts JSON.pretty_generate(results)
    end

    desc 'dev:benchmark', 'Benchmark audit performance', hide: true
    option :iterations, type: :numeric, default: 1, desc: 'Number of iterations'
    def dev_benchmark
      require 'benchmark'
      
      time = Benchmark.measure do
        options[:iterations].times do
          invoke :audit, [], { format: ['json'], interactive: false }
        end
      end
      
      puts "Benchmark results:"
      puts "Total time: #{time.real.round(2)}s"
      puts "Average per iteration: #{(time.real / options[:iterations]).round(2)}s"
    end

    private

    def global_options
      {
        verbose: options[:verbose],
        config: options[:config],
        project_path: options[:project_path]
      }
    end

    # Error handling
    def self.handle_thor_error(error)
      case error
      when Thor::RequiredArgumentMissingError
        puts "Error: #{error.message}".red
        puts "Use 'smartrails help [command]' for usage information."
      when Thor::UnknownArgumentError
        puts "Error: #{error.message}".red
        puts "Use 'smartrails help' to see available commands."
      else
        puts "Unexpected error: #{error.message}".red
        puts error.backtrace if ENV['SMARTRAILS_DEBUG']
      end
      exit(1)
    end
  end
end
