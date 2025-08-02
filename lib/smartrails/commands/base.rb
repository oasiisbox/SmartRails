# frozen_string_literal: true

module SmartRails
  module Commands
    class Base
      include Thor::Shell

      attr_reader :options

      def initialize(options = {})
        @options = options
      end

      protected

      def project_root
        @project_root ||= Pathname.pwd
      end

      def reports_dir
        @reports_dir ||= project_root.join('reports')
      end

      def ensure_directories
        %w[reports logs agents].each do |dir|
          FileUtils.mkdir_p(project_root.join(dir))
        end
      end

      def config_file
        project_root.join('.smartrails.json')
      end

      def project_initialized?
        config_file.exist?
      end

      def load_config
        return {} unless project_initialized?
        JSON.parse(config_file.read)
      rescue JSON::ParserError
        {}
      end

      def save_config(config)
        config_file.write(JSON.pretty_generate(config))
      end
    end
  end
end