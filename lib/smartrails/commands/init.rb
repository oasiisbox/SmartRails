# frozen_string_literal: true

require_relative 'base'

module SmartRails
  module Commands
    class Init < Base
      def execute(project_name)
        say "\n🚀 Initializing SmartRails for: #{project_name}\n", :green

        project_path = Pathname.pwd.join(project_name)
        FileUtils.mkdir_p(project_path)

        Dir.chdir(project_path) do
          config = {
            name: project_name,
            created_at: Time.now,
            version: SmartRails::VERSION,
            features: [],
            rails_version: detect_rails_version,
            ruby_version: RUBY_VERSION
          }

          save_config(config)
          ensure_directories

          say "\n📁 Project structure created successfully!", :blue
          say '📝 Configuration saved in .smartrails.json', :blue
          say "\nNext steps:", :yellow
          say "  cd #{project_name}", :white
          say '  smartrails audit', :white
        end
      end

      private

      def detect_rails_version
        gemfile_path = project_root.join('Gemfile')
        return nil unless gemfile_path.exist?

        gemfile_content = gemfile_path.read
        return unless match = gemfile_content.match(/gem ['"]rails['"],\s*['"]([^'"]+)['"]/)

        match[1]
      end
    end
  end
end
