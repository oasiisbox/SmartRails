# frozen_string_literal: true

module SmartRails
  module Adapters
    class BaseAdapter
      attr_reader :project_path, :options

      def initialize(project_path, options = {})
        @project_path = project_path
        @options = options
      end

      # Must be implemented by subclasses
      def audit
        raise NotImplementedError, "#{self.class} must implement #audit"
      end

      # Optional: implement if tool supports auto-fix
      def auto_fix(issues)
        []
      end

      # Format raw results into standardized format
      def format_results(raw_results)
        raise NotImplementedError, "#{self.class} must implement #format_results"
      end

      # Map tool-specific severity to standard severity
      def severity_mapping(tool_severity)
        :medium
      end

      protected

      # Common helper methods

      def run_command(command)
        output = `cd #{@project_path} && #{command} 2>&1`
        {
          success: $?.success?,
          output: output,
          exit_code: $?.exitstatus
        }
      end

      def file_exists?(relative_path)
        File.exist?(File.join(@project_path, relative_path))
      end

      def read_file(relative_path)
        File.read(File.join(@project_path, relative_path))
      end

      def write_file(relative_path, content)
        File.write(File.join(@project_path, relative_path), content)
      end

      def relative_path(absolute_path)
        absolute_path.sub("#{@project_path}/", '')
      end

      # Standard issue format
      def create_issue(params)
        {
          tool: tool_name,
          type: params[:type] || :general,
          severity: params[:severity] || :medium,
          category: params[:category] || :general,
          message: params[:message],
          file: params[:file],
          line: params[:line],
          column: params[:column],
          fingerprint: params[:fingerprint] || generate_fingerprint(params),
          remediation: params[:remediation],
          auto_fixable: params[:auto_fixable] || false,
          fix_command: params[:fix_command],
          documentation_url: params[:documentation_url],
          metadata: params[:metadata] || {}
        }.compact
      end

      def tool_name
        self.class.name.split('::').last.sub('Adapter', '').downcase.to_sym
      end

      def generate_fingerprint(params)
        require 'digest'
        content = "#{tool_name}:#{params[:file]}:#{params[:line]}:#{params[:message]}"
        Digest::SHA256.hexdigest(content)[0..15]
      end

      # Check if gem is available
      def gem_available?(gem_name)
        require gem_name
        true
      rescue LoadError
        false
      end

      # Parse JSON safely
      def parse_json(content)
        JSON.parse(content)
      rescue JSON::ParserError => e
        Rails.logger.error "JSON parse error: #{e.message}" if defined?(Rails)
        {}
      end

      # Parse YAML safely
      def parse_yaml(content)
        YAML.safe_load(content)
      rescue Psych::SyntaxError => e
        Rails.logger.error "YAML parse error: #{e.message}" if defined?(Rails)
        {}
      end
    end
  end
end