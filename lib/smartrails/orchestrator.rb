# frozen_string_literal: true

require 'parallel'
require 'tty-spinner'
require 'tty-progressbar'

module SmartRails
  class Orchestrator
    attr_reader :project_path, :options, :results

    AUDIT_PIPELINE = [
      {
        phase: :security_critical,
        name: 'Security Critical',
        tools: [:brakeman, :bundler_audit],
        parallel: false,
        stop_on_critical: true
      },
      {
        phase: :quality,
        name: 'Code Quality',
        tools: [:rubocop, :rails_best_practices, :ruby_critic],
        parallel: true,
        stop_on_critical: false
      },
      {
        phase: :database,
        name: 'Database Health',
        tools: [:ar_doctor, :lol_dba, :consistency_fail],
        parallel: false,
        stop_on_critical: false
      },
      {
        phase: :performance,
        name: 'Performance',
        tools: [:bullet_check, :memory_profiler],
        parallel: true,
        stop_on_critical: false
      },
      {
        phase: :cleanup,
        name: 'Code Cleanup',
        tools: [:traceroute, :debride],
        parallel: true,
        stop_on_critical: false
      }
    ].freeze

    def initialize(project_path, options = {})
      @project_path = project_path
      @options = options
      @results = { phases: [], metadata: generate_metadata }
      @available_tools = detect_available_tools
    end

    def run
      start_time = Time.now
      
      AUDIT_PIPELINE.each do |phase_config|
        next unless should_run_phase?(phase_config)
        
        phase_results = run_phase(phase_config)
        @results[:phases] << phase_results
        
        if phase_config[:stop_on_critical] && has_critical_issues?(phase_results)
          @results[:stopped_early] = true
          @results[:stop_reason] = "Critical issues found in #{phase_config[:name]}"
          break
        end
      end
      
      @results[:duration_ms] = ((Time.now - start_time) * 1000).round
      @results[:summary] = generate_summary
      @results[:score] = calculate_scores
      
      @results
    end

    private

    def detect_available_tools
      tools = {}
      
      # Detect installed gems
      tools[:brakeman] = gem_available?('brakeman')
      tools[:bundler_audit] = command_available?('bundle-audit')
      tools[:rubocop] = gem_available?('rubocop')
      tools[:rails_best_practices] = gem_available?('rails_best_practices')
      tools[:ruby_critic] = gem_available?('rubycritic')
      tools[:ar_doctor] = gem_available?('active_record_doctor')
      tools[:lol_dba] = gem_available?('lol_dba')
      tools[:consistency_fail] = gem_available?('consistency_fail')
      tools[:bullet_check] = gem_available?('bullet')
      tools[:traceroute] = gem_available?('traceroute')
      tools[:debride] = gem_available?('debride')
      
      tools
    end

    def gem_available?(gem_name)
      Gem::Specification.find_by_name(gem_name)
      true
    rescue Gem::LoadError
      false
    end

    def command_available?(command)
      system("which #{command} > /dev/null 2>&1")
    end

    def should_run_phase?(phase_config)
      return false if @options[:only] && !@options[:only].include?(phase_config[:phase])
      return false if @options[:skip] && @options[:skip].include?(phase_config[:phase])
      
      # Check if at least one tool is available for this phase
      phase_config[:tools].any? { |tool| @available_tools[tool] }
    end

    def run_phase(phase_config)
      phase_start = Time.now
      issues = []
      
      spinner = TTY::Spinner.new("[:spinner] Running #{phase_config[:name]} phase...", format: :dots)
      spinner.auto_spin
      
      tools_to_run = phase_config[:tools].select { |tool| @available_tools[tool] }
      
      if phase_config[:parallel] && tools_to_run.size > 1
        # Run tools in parallel
        tool_results = Parallel.map(tools_to_run, in_threads: 4) do |tool|
          run_tool(tool)
        end
        issues = tool_results.flatten
      else
        # Run tools sequentially
        tools_to_run.each do |tool|
          tool_result = run_tool(tool)
          issues.concat(tool_result)
        end
      end
      
      spinner.success("(done)")
      
      {
        phase: phase_config[:phase],
        name: phase_config[:name],
        tools_run: tools_to_run,
        duration_ms: ((Time.now - phase_start) * 1000).round,
        issues: issues,
        issue_count: issues.size
      }
    end

    def run_tool(tool_name)
      adapter = load_adapter(tool_name)
      return [] unless adapter
      
      begin
        adapter.audit
      rescue StandardError => e
        Rails.logger.error "Error running #{tool_name}: #{e.message}" if defined?(Rails)
        []
      end
    end

    def load_adapter(tool_name)
      adapter_class = adapter_class_for(tool_name)
      return nil unless adapter_class
      
      adapter_class.new(@project_path, @options)
    end

    def adapter_class_for(tool_name)
      case tool_name
      when :brakeman
        Adapters::BrakemanAdapter
      when :bundler_audit
        Adapters::BundlerAuditAdapter
      when :rubocop
        Adapters::RubocopAdapter
      when :rails_best_practices
        Adapters::RailsBestPracticesAdapter
      when :ruby_critic
        Adapters::RubyCriticAdapter
      when :ar_doctor
        Adapters::ActiveRecordDoctorAdapter
      when :lol_dba
        Adapters::LolDbaAdapter
      when :bullet_check
        Adapters::BulletAdapter
      when :traceroute
        Adapters::TracerouteAdapter
      when :debride
        Adapters::DebrideAdapter
      else
        nil
      end
    end

    def has_critical_issues?(phase_results)
      phase_results[:issues].any? { |issue| issue[:severity] == :critical }
    end

    def generate_metadata
      {
        version: SmartRails::VERSION,
        timestamp: Time.now.iso8601,
        project: File.basename(@project_path),
        rails_version: detect_rails_version,
        ruby_version: RUBY_VERSION,
        platform: RUBY_PLATFORM
      }
    end

    def detect_rails_version
      gemfile_lock = File.join(@project_path, 'Gemfile.lock')
      return 'unknown' unless File.exist?(gemfile_lock)
      
      content = File.read(gemfile_lock)
      if match = content.match(/rails \((\d+\.\d+\.\d+)\)/)
        match[1]
      else
        'unknown'
      end
    end

    def generate_summary
      all_issues = @results[:phases].flat_map { |p| p[:issues] }
      
      {
        total_issues: all_issues.size,
        critical: all_issues.count { |i| i[:severity] == :critical },
        high: all_issues.count { |i| i[:severity] == :high },
        medium: all_issues.count { |i| i[:severity] == :medium },
        low: all_issues.count { |i| i[:severity] == :low },
        auto_fixable: all_issues.count { |i| i[:auto_fixable] },
        tools_available: @available_tools.count { |_, v| v },
        tools_run: @results[:phases].flat_map { |p| p[:tools_run] }.uniq.size
      }
    end

    def calculate_scores
      all_issues = @results[:phases].flat_map { |p| p[:issues] }
      
      # Base score starts at 100
      base_score = 100.0
      
      # Deduct points based on severity
      deductions = {
        critical: 15,
        high: 8,
        medium: 3,
        low: 1
      }
      
      total_deduction = all_issues.sum do |issue|
        deductions[issue[:severity]] || 0
      end
      
      global_score = [base_score - total_deduction, 0].max
      
      # Calculate category scores
      security_issues = all_issues.select { |i| i[:category] == :security }
      quality_issues = all_issues.select { |i| i[:category] == :quality }
      performance_issues = all_issues.select { |i| i[:category] == :performance }
      database_issues = all_issues.select { |i| i[:category] == :database }
      
      {
        global: global_score.round,
        security: calculate_category_score(security_issues),
        quality: calculate_category_score(quality_issues),
        performance: calculate_category_score(performance_issues),
        database: calculate_category_score(database_issues)
      }
    end

    def calculate_category_score(issues)
      return 100 if issues.empty?
      
      deductions = {
        critical: 20,
        high: 10,
        medium: 5,
        low: 2
      }
      
      total_deduction = issues.sum do |issue|
        deductions[issue[:severity]] || 0
      end
      
      [100 - total_deduction, 0].max
    end
  end
end