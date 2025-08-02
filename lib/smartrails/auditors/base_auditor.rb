# frozen_string_literal: true

module SmartRails
  module Auditors
    class BaseAuditor
      attr_reader :project_root, :issues

      def initialize(project_root)
        @project_root = Pathname.new(project_root)
        @issues = []
      end

      def name
        self.class.name.split('::').last.gsub('Auditor', ' Auditor')
      end

      def run
        raise NotImplementedError, 'Subclasses must implement the run method'
      end

      protected

      def add_issue(type:, message:, severity: :medium, file: nil, line: nil, auto_fix: nil)
        issues << {
          type: type,
          message: message,
          severity: severity,
          file: file,
          line: line,
          auto_fix: auto_fix,
          auditor: name
        }
      end

      def rails_app?
        gemfile_path.exist? && gemfile_path.read.include?('rails')
      end

      def gemfile_path
        project_root.join('Gemfile')
      end

      def app_dir
        project_root.join('app')
      end

      def config_dir
        project_root.join('config')
      end

      def file_exists?(*paths)
        paths.any? { |path| project_root.join(path).exist? }
      end

      def read_file(path)
        full_path = project_root.join(path)
        return nil unless full_path.exist?

        full_path.read
      end
    end
  end
end
