# frozen_string_literal: true

require 'yaml'
require 'pathname'

module SmartRails
  class ConfigManager
    DEFAULT_CONFIG = {
      # Audit configuration
      audit: {
        # Phases to run (empty = auto-detect based on project)
        phases: [],
        # Skip specific phases
        skip_phases: [],
        # Output formats (html for user, json for tooling)
        formats: ['html', 'json'],
        # Enable AI analysis
        ai_analysis: true,
        # Interactive confirmations
        interactive: true,
        # Auto-generate badges
        auto_badge: true
      },
      
      # Fix configuration
      fix: {
        # Safety level: safe (default), risky, all
        safety_level: 'safe',
        # Auto-apply safe fixes without confirmation
        auto_apply_safe: false,
        # Create git branches for fixes
        use_git_branches: true,
        # Keep snapshots for rollback
        keep_snapshots: 30, # days
        # Maximum fixes to apply in one session
        max_fixes_per_run: 50
      },
      
      # AI/Suggest configuration
      ai: {
        # Preferred provider: auto, ollama, openai, claude, mistral
        provider: 'auto',
        # Model names per provider
        models: {
          ollama: 'llama3.1',
          openai: 'gpt-4',
          claude: 'claude-3-sonnet',
          mistral: 'mistral-large'
        },
        # Stream responses
        stream: true,
        # Include code context in prompts
        include_context: true,
        # Max context size (lines of code)
        max_context_lines: 100
      },
      
      # Tool-specific configurations
      tools: {
        # Security tools
        brakeman: { enabled: true, confidence_level: 2 },
        bundler_audit: { enabled: true, update_db: true },
        
        # Code quality tools  
        rubocop: { 
          enabled: true, 
          auto_correct: true,
          safe_auto_correct: true
        },
        rails_best_practices: { enabled: true },
        
        # Performance tools
        bullet: { enabled: true },
        
        # Database tools
        active_record_doctor: { enabled: true },
        
        # Dead code detection
        traceroute: { enabled: true },
        debride: { enabled: false } # Can be slow
      },
      
      # Report configuration
      reports: {
        # Output directory (relative to project root)
        output_dir: 'tmp/smartrails_reports',
        # Open HTML report automatically
        auto_open: false,
        # Include diff previews in reports
        include_diffs: true,
        # Badge integration
        badge: {
          enabled: true,
          update_readme: false,
          format: 'markdown'
        }
      },
      
      # Project-specific settings
      project: {
        # Rails version (auto-detected if nil)
        rails_version: nil,
        # Ruby version (auto-detected if nil)  
        ruby_version: nil,
        # Project name (auto-detected from directory)
        name: nil,
        # Ignore patterns (in addition to .gitignore)
        ignore_patterns: [
          'tmp/**/*',
          'log/**/*',
          'coverage/**/*',
          'node_modules/**/*'
        ]
      }
    }.freeze

    CONFIG_FILE = '.smartrails.yml'

    attr_reader :config, :project_path

    def initialize(project_path = '.')
      @project_path = Pathname.new(project_path).expand_path
      @config_file = @project_path.join(CONFIG_FILE)
      @config = load_config
    end

    def get(key_path)
      keys = key_path.to_s.split('.')
      keys.reduce(@config) { |config, key| config&.dig(key.to_sym) }
    end

    def enabled?(tool_name)
      get("tools.#{tool_name}.enabled") != false
    end

    def audit_phases
      phases = get('audit.phases')
      return detect_phases if phases.nil? || phases.empty?
      
      phases
    end

    def skip_phases
      get('audit.skip_phases') || []
    end

    def output_formats
      get('audit.formats') || ['html', 'json']
    end

    def ai_enabled?
      get('audit.ai_analysis') != false
    end

    def interactive?
      get('audit.interactive') != false
    end

    def safety_level
      get('fix.safety_level') || 'safe'
    end

    def auto_apply_safe?
      get('fix.auto_apply_safe') == true
    end

    def ai_provider
      provider = get('ai.provider') || 'auto'
      return detect_ai_provider if provider == 'auto'
      
      provider
    end

    def ai_model(provider = nil)
      provider ||= ai_provider
      get("ai.models.#{provider}")
    end

    def create_default_config!
      return false if @config_file.exist?

      config_content = generate_config_file_content
      @config_file.write(config_content)
      true
    end

    def config_exists?
      @config_file.exist?
    end

    private

    def load_config
      if @config_file.exist?
        user_config = YAML.safe_load(@config_file.read, symbolize_names: true) || {}
        deep_merge(DEFAULT_CONFIG, user_config)
      else
        DEFAULT_CONFIG.dup
      end
    rescue Psych::SyntaxError => e
      warn "Warning: Invalid YAML in #{CONFIG_FILE}: #{e.message}"
      warn "Using default configuration."
      DEFAULT_CONFIG.dup
    end

    def detect_phases
      phases = []
      
      # Always run security first
      phases << 'security'
      
      # Code quality if RuboCop config exists
      phases << 'quality' if rubocop_configured?
      
      # Database if Rails app with migrations
      phases << 'database' if rails_app_with_db?
      
      # Performance if Rails app
      phases << 'performance' if rails_app?
      
      # Cleanup if needed
      phases << 'cleanup' if cleanup_needed?
      
      phases
    end

    def detect_ai_provider
      # Check for available providers in order of preference
      return 'claude' if claude_available?
      return 'openai' if openai_available?
      return 'ollama' if ollama_available?
      
      'ollama' # fallback
    end

    def rubocop_configured?
      @project_path.join('.rubocop.yml').exist? ||
        @project_path.join('Gemfile').read.include?('rubocop')
    rescue
      false
    end

    def rails_app?
      @project_path.join('config', 'application.rb').exist?
    end

    def rails_app_with_db?
      rails_app? && @project_path.join('db', 'migrate').exist?
    end

    def cleanup_needed?
      # Heuristic: cleanup if it's a larger Rails app
      rails_app? && Dir.glob(@project_path.join('app', '**', '*.rb')).count > 50
    end

    def claude_available?
      ENV['ANTHROPIC_API_KEY'] && !ENV['ANTHROPIC_API_KEY'].empty?
    end

    def openai_available?
      ENV['OPENAI_API_KEY'] && !ENV['OPENAI_API_KEY'].empty?
    end

    def ollama_available?
      system('which ollama > /dev/null 2>&1')
    end

    def deep_merge(base, override)
      merger = proc do |_key, base_val, override_val|
        if base_val.is_a?(Hash) && override_val.is_a?(Hash)
          base_val.merge(override_val, &merger)
        else
          override_val
        end
      end
      
      base.merge(override, &merger)
    end

    def generate_config_file_content
      <<~YAML
        # SmartRails Configuration
        # This file allows you to customize SmartRails behavior.
        # SmartRails works great out-of-the-box, so most settings are optional.
        
        # Audit settings
        audit:
          # Phases to run (empty = auto-detect based on your project)
          # Available: security, quality, database, performance, cleanup
          phases: []
          
          # Skip specific phases if needed
          skip_phases: []
          
          # Output formats (html for reading, json for tooling)
          formats: ['html', 'json']
          
          # Enable AI analysis and recommendations
          ai_analysis: true
          
          # Interactive confirmations
          interactive: true
        
        # Fix settings
        fix:
          # Safety level: safe (recommended), risky, all
          safety_level: 'safe'
          
          # Auto-apply safe fixes (formatting, style) without asking
          auto_apply_safe: false
          
          # Use Git branches for safer fix application
          use_git_branches: true
          
          # Keep snapshots for rollback (days)
          keep_snapshots: 30
        
        # AI settings
        ai:
          # Provider: auto (recommended), ollama, openai, claude, mistral
          provider: 'auto'
          
          # Models per provider (optional - uses sensible defaults)
          models:
            ollama: 'llama3.1'
            openai: 'gpt-4'
            claude: 'claude-3-sonnet'
          
          # Stream responses for real-time feedback
          stream: true
        
        # Tool-specific settings (rarely needed)
        tools:
          # Security
          brakeman:
            enabled: true
            confidence_level: 2  # 1=high, 2=medium, 3=low
          
          # Code quality
          rubocop:
            enabled: true
            auto_correct: true
            safe_auto_correct: true
          
          # Performance
          bullet:
            enabled: true
        
        # Report settings
        reports:
          output_dir: 'tmp/smartrails_reports'
          auto_open: false  # Open HTML report automatically
          
          badge:
            enabled: true
            update_readme: false  # Auto-update README with quality badge
      YAML
    end
  end
end