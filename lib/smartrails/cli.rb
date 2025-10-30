# frozen_string_literal: true

require 'optparse'
require 'json'
require 'pathname'

module SmartRails
  # Lightweight command-line interface to run a SmartRails audit.
  class CLI
    DEFAULT_FORMAT = :text

    def initialize(argv)
      @argv = argv.dup
    end

    def run
      options = { format: DEFAULT_FORMAT }
      parser = build_parser(options)
      parser.order!(@argv)

      if options[:show_version]
        puts "SmartRails v#{SmartRails::VERSION}"
        return 0
      end

      if options[:show_help]
        puts parser
        return 0
      end

      project_path = @argv.shift
      unless project_path
        warn 'Error: you must supply the path to a Rails project.'
        warn parser
        return 1
      end

      result = audit_project(project_path)
      print_result(result, options[:format])
      result.ok? ? 0 : 2
    rescue OptionParser::ParseError => e
      warn e.message
      warn
      warn build_parser.to_s
      1
    end

    private

    def build_parser(options = {})
      OptionParser.new do |opts|
        opts.banner = 'Usage: smartrails [options] PATH'
        opts.separator ''
        opts.separator 'Options:'

        opts.on('-f', '--format FORMAT', 'Output format (text or json)') do |format|
          options[:format] = format.to_s.downcase.to_sym
        end

        opts.on('-v', '--version', 'Show SmartRails version') do
          options[:show_version] = true
        end

        opts.on('-h', '--help', 'Show this help message') do
          options[:show_help] = true
        end
      end
    end

    def audit_project(path)
      result = SmartRails::AuditResult.new(project_path: path)

      unless result.project_path.exist?
        result.add_issue(:project, "Path does not exist: #{result.project_path}")
        return result
      end

      unless result.project_path.directory?
        result.add_issue(:project, "Path is not a directory: #{result.project_path}")
        return result
      end

      rails_application = result.project_path.join('config', 'application.rb')
      unless rails_application.file?
        result.add_issue(:project, 'config/application.rb not found. Is this a Rails project?')
      end

      result
    end

    def print_result(result, format)
      case format
      when :json
        puts(JSON.pretty_generate(result: serialize_result(result)))
      else
        print_text_result(result)
      end
    end

    def serialize_result(result)
      {
        project_path: result.project_path.to_s,
        ok: result.ok?,
        findings: result.findings.map do |finding|
          {
            category: finding.category,
            message: finding.message,
            details: finding.details
          }.compact
        end
      }
    end

    def print_text_result(result)
      puts "SmartRails audit for #{result.project_path}"
      if result.ok?
        puts 'No issues detected.'
      else
        puts 'Findings:'
        result.findings.each_with_index do |finding, index|
          puts format('%<index>2d. [%<category>s] %<message>s', index: index + 1, category: finding.category, message: finding.message)
          puts "    Details: #{finding.details}" if finding.details
        end
      end
    end
  end
end
