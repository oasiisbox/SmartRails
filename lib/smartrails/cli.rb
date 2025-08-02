# frozen_string_literal: true

require 'thor'
require 'json'
require 'fileutils'
require 'pathname'

require_relative 'commands/init'
require_relative 'commands/audit'
require_relative 'commands/suggest'
require_relative 'commands/serve'
require_relative 'version'

module SmartRails
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc 'version', 'Display SmartRails version'
    def version
      say "SmartRails v#{SmartRails::VERSION}", :blue
    end

    desc 'init PROJECT_NAME', 'Initialize a new SmartRails project'
    def init(project_name)
      Commands::Init.new(options).execute(project_name)
    end

    desc 'audit', 'Run an interactive or automatic audit of the current Rails project'
    option :auto, type: :boolean, default: false, desc: 'Run audit without user interaction'
    option :format, type: :string, default: 'json', desc: 'Output format (json, html)'
    option :fix, type: :boolean, default: false, desc: 'Automatically fix issues when possible'
    def audit
      Commands::Audit.new(options).execute
    end

    desc 'suggest [SOURCE]', 'Use LLM to generate suggestions from a file or message'
    option :file, aliases: '-f', type: :string, desc: 'Path to file to analyze'
    option :llm, aliases: '-l', type: :string, default: 'ollama', desc: 'LLM model to use (ollama, openai, mistral)'
    option :model, aliases: '-m', type: :string, desc: 'Specific model name to use'
    def suggest(source = nil)
      Commands::Suggest.new(options).execute(source)
    end

    desc 'serve', 'Launch a local web interface to view reports'
    option :port, aliases: '-p', type: :numeric, default: 4567, desc: 'Port to run the server on'
    option :host, aliases: '-h', type: :string, default: 'localhost', desc: 'Host to bind to'
    def serve
      Commands::Serve.new(options).execute
    end

    desc 'check:llm', 'Check LLM connection'
    def check_llm
      Commands::Suggest.new(options).check_connection
    end
  end
end
