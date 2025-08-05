# frozen_string_literal: true

module SpecHelpers
  module RailsProjectHelper
    # Simple camelize implementation
    def camelize(string)
      string.split('_').map(&:capitalize).join
    end
    def create_temp_rails_project(name = 'test_project')
      @temp_dir = Dir.mktmpdir
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

        module #{camelize(name)}
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

      project_dir
    end

    def create_rails_controller(project_dir, name, content = nil)
      controller_file = File.join(project_dir, 'app', 'controllers', "#{name}_controller.rb")

      content ||= <<~RUBY
        class #{camelize(name)}Controller < ApplicationController
          def index
          end
        end
      RUBY

      File.write(controller_file, content)
      controller_file
    end

    def create_rails_model(project_dir, name, content = nil)
      model_file = File.join(project_dir, 'app', 'models', "#{name}.rb")

      content ||= <<~RUBY
        class #{camelize(name)} < ApplicationRecord
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
