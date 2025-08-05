# frozen_string_literal: true

module SmartRails
  module Adapters
    class RubocopAdapter < BaseAdapter
      SEVERITY_MAPPING = {
        'error' => :high,
        'warning' => :medium,
        'convention' => :low,
        'refactor' => :low,
        'info' => :low
      }.freeze

      AUTO_FIXABLE_COPS = [
        'Style/StringLiterals',
        'Style/TrailingCommaInArrayLiteral',
        'Style/TrailingCommaInHashLiteral',
        'Layout/TrailingWhitespace',
        'Layout/IndentationConsistency',
        'Style/EmptyLines',
        'Style/Documentation',
        'Rails/HttpPositionalArguments'
      ].freeze

      def audit
        return [] unless gem_available?('rubocop')
        
        require 'rubocop'
        
        begin
          # Run RuboCop with JSON formatter
          result = run_command('bundle exec rubocop --format json')
          
          return [] unless result[:success] || result[:output].include?('"files"')
          
          # Parse JSON output
          data = parse_json(result[:output])
          
          format_results(data)
        rescue StandardError => e
          Rails.logger.error "RuboCop error: #{e.message}" if defined?(Rails)
          []
        end
      end

      def auto_fix(issues)
        return [] if issues.empty?
        
        # Group issues by file for efficient fixing
        issues_by_file = issues.group_by { |issue| issue[:file] }
        fixes_applied = []
        
        issues_by_file.each do |file, file_issues|
          next unless file_issues.any? { |issue| issue[:auto_fixable] }
          
          # Extract cop names for auto-fixable issues
          auto_fixable_cops = file_issues
            .select { |issue| issue[:auto_fixable] }
            .map { |issue| issue[:metadata][:cop_name] }
            .uniq
          
          if auto_fixable_cops.any?
            fix_result = run_rubocop_autocorrect(file, auto_fixable_cops)
            fixes_applied << fix_result if fix_result[:success]
          end
        end
        
        fixes_applied
      end

      private

      def format_results(data)
        issues = []
        
        return issues unless data['files']
        
        data['files'].each do |file_data|
          next unless file_data['offenses']
          
          file_path = relative_path(file_data['path'])
          
          file_data['offenses'].each do |offense|
            issues << create_issue(
              type: :quality,
              severity: SEVERITY_MAPPING[offense['severity']] || :medium,
              category: determine_category(offense['cop_name']),
              message: offense['message'],
              file: file_path,
              line: offense['location']['line'],
              column: offense['location']['column'],
              remediation: generate_remediation(offense),
              auto_fixable: offense['correctable'] && AUTO_FIXABLE_COPS.include?(offense['cop_name']),
              fix_command: generate_fix_command(offense, file_path),
              documentation_url: generate_doc_url(offense['cop_name']),
              metadata: {
                cop_name: offense['cop_name'],
                correctable: offense['correctable'],
                severity: offense['severity']
              }
            )
          end
        end
        
        issues
      end

      def determine_category(cop_name)
        case cop_name
        when /^Security\//
          :security
        when /^Performance\//
          :performance
        when /^Rails\//
          :rails
        when /^Style\//, /^Layout\//
          :style
        when /^Lint\//
          :lint
        when /^Metrics\//
          :metrics
        else
          :quality
        end
      end

      def generate_remediation(offense)
        case offense['cop_name']
        when 'Style/Documentation'
          'Add class/module documentation comment'
        when 'Rails/HttpPositionalArguments'
          'Use keyword arguments for HTTP methods in tests'
        when 'Style/StringLiterals'
          "Use #{preferred_string_style} quotes for string literals"
        when 'Layout/TrailingWhitespace'
          'Remove trailing whitespace'
        when /^Metrics\//
          'Consider refactoring to reduce complexity'
        else
          offense['message']
        end
      end

      def generate_fix_command(offense, file_path)
        if offense['correctable']
          "bundle exec rubocop --auto-correct --only #{offense['cop_name']} #{file_path}"
        else
          nil
        end
      end

      def generate_doc_url(cop_name)
        "https://docs.rubocop.org/rubocop/cops_#{cop_name.downcase.gsub('::', '/').gsub('/', '_')}.html"
      end

      def run_rubocop_autocorrect(file_path, cop_names)
        cops_arg = cop_names.join(',')
        command = "bundle exec rubocop --auto-correct --only #{cops_arg} #{file_path}"
        
        result = run_command(command)
        
        if result[:success]
          {
            success: true,
            description: "Auto-corrected #{cow_names.size} RuboCop offenses in #{file_path}",
            files_modified: [file_path],
            cops_fixed: cop_names
          }
        else
          {
            success: false,
            reason: "RuboCop auto-correct failed: #{result[:output]}",
            command: command
          }
        end
      end

      def preferred_string_style
        # Try to detect from .rubocop.yml
        config_file = File.join(@project_path, '.rubocop.yml')
        return 'single' unless File.exist?(config_file)
        
        begin
          config = parse_yaml(read_file('.rubocop.yml'))
          string_literals = config.dig('Style', 'StringLiterals', 'EnforcedStyle')
          string_literals == 'double_quotes' ? 'double' : 'single'
        rescue
          'single'
        end
      end

      def rubocop_config_present?
        file_exists?('.rubocop.yml') || file_exists?('.rubocop.yaml')
      end

      def create_default_rubocop_config
        config_content = <<~YAML
          require:
            - rubocop-rails
            - rubocop-performance
          
          AllCops:
            TargetRubyVersion: 2.7
            NewCops: enable
            Exclude:
              - 'db/**/*'
              - 'config/**/*'
              - 'vendor/**/*'
              - 'bin/**/*'
              - 'node_modules/**/*'
          
          # Relaxed rules for better Rails compatibility
          Style/Documentation:
            Enabled: false
          
          Layout/LineLength:
            Max: 120
          
          Metrics/BlockLength:
            Exclude:
              - 'spec/**/*'
              - 'config/routes.rb'
        YAML
        
        write_file('.rubocop.yml', config_content)
      end
    end
  end
end