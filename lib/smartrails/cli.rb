# frozen_string_literal: true

require 'thor'
require 'json'
require 'fileutils'
require 'pathname'
require 'tty-prompt'
require 'colorize'

require_relative 'commands/audit'
require_relative 'commands/fix'
require_relative 'commands/suggest'
require_relative 'config_manager'
require_relative 'version'

module SmartRails
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    # Minimal global options - complexity moved to config file
    class_option :verbose, aliases: '-v', type: :boolean, default: false, desc: 'Enable verbose output'
    class_option :project_path, aliases: '-p', type: :string, desc: 'Path to Rails project', default: '.'

    desc 'version', 'Display SmartRails version'
    def version
      say "SmartRails v#{SmartRails::VERSION}".blue
      say "Ruby #{RUBY_VERSION} on #{RUBY_PLATFORM}"
      say "The ultra-simple Rails audit and fix tool"
      say ""
      say "Three commands. That's it."
      say "  smartrails audit   # Complete audit + recommendations"
      say "  smartrails fix     # Apply safe fixes automatically"
      say "  smartrails suggest # AI-powered guidance"
    end

    desc 'audit', 'Complete Rails project audit with intelligent prioritization'
    long_desc <<-LONGDESC
      SmartRails runs a comprehensive, intelligent audit of your Rails project:
      
      🔍 WHAT IT DOES:
      • Security analysis (vulnerabilities, secrets, CSRF, etc.)
      • Code quality assessment (style, complexity, best practices)
      • Performance audit (N+1 queries, missing indexes, etc.)
      • Database health check (migrations, constraints, etc.)
      • Dependency analysis (outdated gems, CVEs, etc.)
      
      📊 INTELLIGENT ORCHESTRATION:
      • Automatically detects your Rails version and environment
      • Prioritizes critical issues first (security > performance > style)
      • Suggests immediate actions and long-term improvements
      • Generates actionable reports (HTML + JSON)
      
      🤖 BUILT-IN AI ANALYSIS:
      • Contextual recommendations for your specific codebase
      • Action plans with step-by-step guidance
      • Risk assessment and impact analysis
      
      No complex options needed - SmartRails figures out what to run based on your project.
      Advanced users can customize behavior via .smartrails.yml config file.
    LONGDESC
    option :dry_run, type: :boolean, default: false, desc: 'Preview what would be audited without running'
    def audit
      Commands::Audit.new(options.merge(global_options)).execute
    end

    desc 'fix', 'Apply intelligent automatic fixes with triple-safety architecture'
    long_desc <<-LONGDESC
      SmartRails applies fixes safely and intelligently:
      
      🛡️ TRIPLE-SAFETY ARCHITECTURE:
      • Creates complete project snapshot before any changes
      • Uses dedicated Git branches for all modifications  
      • Validates every change before making it permanent
      • Automatic rollback on any failure or validation error
      
      🎯 INTELLIGENT FIX PRIORITIZATION:
      • Applies safe fixes automatically (formatting, style, etc.)
      • Asks confirmation for risky fixes (security, logic changes)
      • Shows impact assessment and rollback options for each fix
      • Never applies destructive changes without explicit approval
      
      📋 WHAT GETS FIXED:
      • RuboCop violations (style, formatting, best practices)
      • Security issues (CSRF tokens, hardcoded secrets, etc.)
      • Performance problems (N+1 queries, missing indexes)
      • Dependency vulnerabilities (gem updates, patches)
      
      🔄 ROLLBACK & HISTORY:
      • Complete fix history with timestamps and descriptions
      • One-command rollback to any previous state
      • Git integration preserves your existing workflow
      
      SmartRails chooses the right fixes automatically. No complex options needed.
    LONGDESC
    option :dry_run, type: :boolean, default: false, desc: 'Preview all changes without applying any'
    option :rollback, type: :string, desc: 'Rollback to specific snapshot (use: smartrails fix --rollback SNAPSHOT_ID)'
    def fix
      Commands::Fix.new(options.merge(global_options)).execute
    end

    desc 'suggest [QUESTION]', 'AI-powered guidance and recommendations'
    long_desc <<-LONGDESC
      Get intelligent, contextual guidance from AI:
      
      🤖 SMART ANALYSIS:
      • Automatically uses your latest audit results for context
      • Provides specific, actionable recommendations for your codebase
      • Explains complex issues in simple terms
      • Suggests step-by-step action plans
      
      💡 USAGE EXAMPLES:
        smartrails suggest                           # Analyze latest audit results
        smartrails suggest "How to improve security?" # Ask specific questions
        smartrails suggest "app/models/user.rb"      # Analyze specific file
        smartrails suggest "Fix N+1 queries"         # Get targeted advice
      
      🔧 INTELLIGENT CONTEXT:
      • Knows your Rails version, gems, and project structure
      • References your specific audit results and issues
      • Provides code examples tailored to your setup
      • Suggests both quick fixes and long-term improvements
      
      🎯 AI PROVIDERS:
      SmartRails automatically detects available AI providers (Ollama, OpenAI, Claude)
      and chooses the best one for your query. Configure preferred provider in .smartrails.yml
    LONGDESC
    def suggest(question = nil)
      Commands::Suggest.new(options.merge(global_options)).execute(question)
    end

    private

    def global_options
      {
        verbose: options[:verbose],
        project_path: options[:project_path]
      }
    end

    # Simplified error handling with helpful guidance
    def self.handle_thor_error(error)
      case error
      when Thor::RequiredArgumentMissingError
        puts "\n❌ Missing required argument: #{error.message}".red
        puts "\n💡 SmartRails uses just 3 simple commands:"
        puts "   smartrails audit     # Complete project audit"
        puts "   smartrails fix       # Apply safe fixes automatically"
        puts "   smartrails suggest   # Get AI-powered guidance"
        puts "\nFor detailed help: smartrails help [command]"
      when Thor::UnknownArgumentError
        puts "\n❌ Unknown option: #{error.message}".red
        puts "\n💡 SmartRails keeps it simple - most options are auto-configured."
        puts "   Use .smartrails.yml for advanced customization."
        puts "\nAvailable commands: audit, fix, suggest"
        puts "For help: smartrails help"
      else
        puts "\n❌ Unexpected error: #{error.message}".red
        puts "\n💡 Try running with --verbose for more details"
        puts error.backtrace if ENV['SMARTRAILS_DEBUG']
      end
      exit(1)
    end
  end
end
