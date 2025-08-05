# frozen_string_literal: true

require 'parallel'
require 'tty-spinner'
require 'tty-progressbar'
require_relative 'config_manager'

module SmartRails
  class Orchestrator
    attr_reader :project_path, :options, :results

    # Intelligent pipeline - adapts based on project characteristics
    def build_audit_pipeline
      pipeline = []
      
      # Security always comes first (critical)
      if should_run_phase?('security')
        pipeline << {
          phase: :security,
          name: '🔒 Security Analysis',
          tools: [:brakeman, :bundler_audit],
          parallel: false,
          stop_on_critical: true,
          priority: 1
        }
      end
      
      # Code quality (high priority for maintainability)
      if should_run_phase?('quality')
        pipeline << {
          phase: :quality,
          name: '📊 Code Quality',
          tools: [:rubocop, :rails_best_practices],
          parallel: true,
          stop_on_critical: false,
          priority: 2
        }
      end
      
      # Performance (high impact on user experience)
      if should_run_phase?('performance')
        pipeline << {
          phase: :performance,
          name: '⚡ Performance',
          tools: [:bullet_check],
          parallel: true,
          stop_on_critical: false,
          priority: 3
        }
      end
      
      # Database health (important for data integrity)
      if should_run_phase?('database')
        pipeline << {
          phase: :database,
          name: '🗄️ Database Health',
          tools: [:ar_doctor],
          parallel: false,
          stop_on_critical: false,
          priority: 4
        }
      end
      
      # Code cleanup (nice to have)
      if should_run_phase?('cleanup')
        pipeline << {
          phase: :cleanup,
          name: '🧹 Code Cleanup',
          tools: [:traceroute],
          parallel: true,
          stop_on_critical: false,
          priority: 5
        }
      end
      
      pipeline.sort_by { |phase| phase[:priority] }
    end

    def initialize(project_path, options = {})
      @project_path = project_path
      @options = options
      @config = ConfigManager.new(project_path)
      @results = { phases: [], metadata: generate_metadata }
      @available_tools = detect_available_tools
    end

    def run
      start_time = Time.now
      pipeline = build_audit_pipeline
      
      puts "\n🚀 SmartRails Intelligent Audit Pipeline".blue.bold
      puts "Analyzing #{File.basename(@project_path)} (#{detect_project_type})".light_blue
      puts "=" * 60
      
      pipeline.each do |phase_config|
        phase_results = run_phase(phase_config)
        @results[:phases] << phase_results
        
        # Smart stopping logic
        if phase_config[:stop_on_critical] && has_critical_issues?(phase_results)
          puts "\\n🚨 Critical security issues found - stopping for immediate attention".red.bold
          @results[:stopped_early] = true
          @results[:stop_reason] = "Critical security issues require immediate attention"
          @results[:critical_issues] = extract_critical_issues(phase_results)
          break
        end
      end
      
      @results[:duration_ms] = ((Time.now - start_time) * 1000).round
      @results[:summary] = generate_summary
      @results[:score] = calculate_scores
      @results[:recommendations] = generate_intelligent_recommendations
      
      display_completion_summary
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

    def should_run_phase?(phase_name)
      # Check config first
      return false if @config.skip_phases.include?(phase_name)
      
      # If specific phases requested, honor that
      requested_phases = @config.audit_phases
      return requested_phases.include?(phase_name) unless requested_phases.empty?
      
      # Auto-detection based on project characteristics
      case phase_name
      when 'security'
        true # Always run security
      when 'quality'
        has_rubocop_config? || has_quality_tools?
      when 'performance'
        rails_app? && has_performance_tools?
      when 'database'
        rails_app_with_database?
      when 'cleanup'
        large_rails_app? && has_cleanup_tools?
      else
        false
      end
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

    # New intelligent methods
    def detect_project_type
      return "Rails #{detect_rails_version}" if rails_app?
      return "Ruby Gem" if gem_project?
      return "Ruby Project" if ruby_project?
      "Unknown Project"
    end

    def has_rubocop_config?
      File.exist?(File.join(@project_path, '.rubocop.yml')) ||
        File.exist?(File.join(@project_path, '.rubocop.yaml'))
    end

    def has_quality_tools?
      @available_tools[:rubocop] || @available_tools[:rails_best_practices]
    end

    def has_performance_tools?
      @available_tools[:bullet_check]
    end

    def has_cleanup_tools?
      @available_tools[:traceroute] || @available_tools[:debride]
    end

    def rails_app?
      File.exist?(File.join(@project_path, 'config', 'application.rb'))
    end

    def rails_app_with_database?
      rails_app? && File.exist?(File.join(@project_path, 'db', 'migrate'))
    end

    def large_rails_app?
      return false unless rails_app?
      
      ruby_files = Dir.glob(File.join(@project_path, 'app', '**', '*.rb')).count
      ruby_files > 50
    end

    def gem_project?
      Dir.glob(File.join(@project_path, '*.gemspec')).any?
    end

    def ruby_project?
      File.exist?(File.join(@project_path, 'Gemfile')) ||
        Dir.glob(File.join(@project_path, '**', '*.rb')).any?
    end

    def extract_critical_issues(phase_results)
      phase_results[:issues].select { |issue| issue[:severity] == :critical }
    end

    def generate_intelligent_recommendations
      all_issues = @results[:phases].flat_map { |p| p[:issues] }
      
      recommendations = {
        immediate: [],
        short_term: [],
        long_term: []
      }

      # Immediate actions (critical/high severity)
      critical_count = all_issues.count { |i| i[:severity] == :critical }
      high_count = all_issues.count { |i| i[:severity] == :high }
      
      if critical_count > 0
        recommendations[:immediate] << "🚨 Address #{critical_count} critical security issues immediately"
        recommendations[:immediate] << "💡 Run 'smartrails fix' to apply automated security fixes"
      end

      auto_fixable = all_issues.count { |i| i[:auto_fixable] }
      if auto_fixable > 0
        recommendations[:immediate] << "⚡ Apply #{auto_fixable} automatic fixes with 'smartrails fix'"
      end

      # Short-term improvements
      if high_count > 3
        recommendations[:short_term] << "🎯 Focus on #{high_count} high-priority issues"
      end

      if @results[:score][:quality] < 80
        recommendations[:short_term] << "📈 Improve code quality with consistent linting and formatting"
      end

      # Long-term strategy
      if @results[:score][:global] < 70
        recommendations[:long_term] << "🏗️ Establish code review process and continuous monitoring"
        recommendations[:long_term] << "📚 Consider team training on Rails security best practices"
      end

      if !@config.config_exists?
        recommendations[:long_term] << "⚙️ Create .smartrails.yml for project-specific customization"
      end

      recommendations
    end

    def display_completion_summary
      puts "\\n" + "=" * 60
      puts "📊 Audit Complete".green.bold
      puts "=" * 60
      
      summary = @results[:summary]
      score = @results[:score][:global]
      
      # Score with color
      score_color = case score
                   when 90..100 then :green
                   when 70..89 then :yellow
                   when 50..69 then :light_red
                   else :red
                   end
      
      puts "🎯 Overall Score: #{score}%".colorize(score_color).bold
      puts "📈 Issues Found: #{summary[:total_issues]} (#{summary[:auto_fixable]} auto-fixable)"
      puts "⏱️  Duration: #{@results[:duration_ms]}ms"
      
      # Next steps
      if @results[:recommendations]
        puts "\\n💡 Next Steps:".blue.bold
        
        if @results[:recommendations][:immediate].any?
          puts "   Immediate:".red.bold
          @results[:recommendations][:immediate].each { |rec| puts "   • #{rec}" }
        end
        
        if summary[:auto_fixable] > 0
          puts "\\n🔧 Ready to fix #{summary[:auto_fixable]} issues automatically?"
          puts "   Run: smartrails fix"
        end
      end
      
      puts "\\n📄 Detailed report: tmp/smartrails_reports/smartrails_report.html"
    end
  end
end