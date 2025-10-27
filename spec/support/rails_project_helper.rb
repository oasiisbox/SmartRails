# frozen_string_literal: true

module SpecHelpers
  module RailsProjectHelper
    def setup_temp_dir
      @temp_dir = Dir.mktmpdir
    end

    def cleanup_temp_dir
      FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
      @temp_dir = nil
    end

    def create_rails_project(name = 'test_project')
      setup_temp_dir unless @temp_dir
      project_dir = File.join(@temp_dir, name)
      Dir.mkdir(project_dir)

      # Create basic Rails directory structure
      %w[app config db lib spec test].each do |dir|
        Dir.mkdir(File.join(project_dir, dir))
      end

      %w[controllers models views helpers].each do |dir|
        Dir.mkdir(File.join(project_dir, 'app', dir))
      end

      %w[environments initializers].each do |dir|
        Dir.mkdir(File.join(project_dir, 'config', dir))
      end

      # Create Gemfile
      File.write(File.join(project_dir, 'Gemfile'), <<~GEMFILE)
        source 'https://rubygems.org'

        gem 'rails', '~> 7.0.0'
        gem 'sqlite3', '~> 1.4'
      GEMFILE

      # Create basic Rails application file
      File.write(File.join(project_dir, 'config', 'application.rb'), <<~RUBY)
        require_relative 'boot'
        require 'rails/all'

        module TestApp
          class Application < Rails::Application
            config.load_defaults 7.0
          end
        end
      RUBY

      # Create application controller
      File.write(File.join(project_dir, 'app', 'controllers', 'application_controller.rb'), <<~RUBY)
        class ApplicationController < ActionController::Base
        end
      RUBY

      # Create README
      File.write(File.join(project_dir, 'README.md'), "# #{name}\n")

      project_dir
    end

    # Alias for backward compatibility
    alias create_temp_rails_project create_rails_project

    def create_controller(project_dir, name, content = nil)
      controller_file = File.join(project_dir, 'app', 'controllers', "#{name}_controller.rb")

      content ||= <<~RUBY
        class #{name.capitalize}Controller < ApplicationController
          def index
          end
        end
      RUBY

      File.write(controller_file, content)
      controller_file
    end

    # Alias for backward compatibility
    alias create_rails_controller create_controller

    def create_rails_model(project_dir, name, content = nil)
      model_file = File.join(project_dir, 'app', 'models', "#{name}.rb")

      content ||= <<~RUBY
        class #{name.capitalize} < ApplicationRecord
        end
      RUBY

      File.write(model_file, content)
      model_file
    end

    def create_config_file(project_dir, filename, content)
      config_file = File.join(project_dir, 'config', filename)
      File.write(config_file, content)
      config_file
    end
  end
end
