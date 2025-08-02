# frozen_string_literal: true

require_relative 'base_auditor'

module SmartRails
  module Auditors
    class PerformanceAuditor < BaseAuditor
      def run
        check_caching_configuration
        check_database_queries
        check_asset_optimization
        check_background_jobs
        check_pagination
        check_eager_loading

        issues
      end

      private

      def check_caching_configuration
        # Check production caching
        production_rb = read_file('config/environments/production.rb')
        return unless production_rb

        unless production_rb.include?('config.cache_store')
          add_issue(
            type: 'Caching',
            message: 'No cache store configured for production',
            severity: :medium,
            file: 'config/environments/production.rb'
          )
        end

        # Check for Redis
        return if gemfile_path.read.include?('redis')

        add_issue(
          type: 'Caching',
          message: 'Redis gem not found - consider using Redis for caching',
          severity: :low,
          file: 'Gemfile'
        )
      end

      def check_database_queries
        # Check for query optimization tools
        gemfile_content = gemfile_path.read

        unless gemfile_content.include?('rack-mini-profiler')
          add_issue(
            type: 'Performance Monitoring',
            message: 'rack-mini-profiler not found - consider adding for development profiling',
            severity: :low,
            file: 'Gemfile'
          )
        end

        # Check for database connection pooling
        database_yml = read_file('config/database.yml')
        return unless database_yml && !database_yml.include?('pool:')

        add_issue(
          type: 'Database Performance',
          message: 'Database connection pool not configured',
          severity: :medium,
          file: 'config/database.yml'
        )
      end

      def check_asset_optimization
        # Check for asset precompilation in production
        production_rb = read_file('config/environments/production.rb')
        return unless production_rb

        unless production_rb.include?('config.assets.compile = false')
          add_issue(
            type: 'Asset Performance',
            message: 'Asset compilation enabled in production - should be precompiled',
            severity: :high,
            file: 'config/environments/production.rb'
          )
        end

        # Check for CDN configuration
        unless production_rb.include?('config.asset_host') ||
               production_rb.include?('config.action_controller.asset_host')
          add_issue(
            type: 'Asset Performance',
            message: 'No CDN configured for assets',
            severity: :low,
            file: 'config/environments/production.rb'
          )
        end
      end

      def check_background_jobs
        gemfile_content = gemfile_path.read
        job_gems = %w[sidekiq resque delayed_job good_job]

        return if job_gems.any? { |gem| gemfile_content.include?(gem) }

        add_issue(
          type: 'Background Jobs',
          message: 'No background job processor found - consider adding for async tasks',
          severity: :medium,
          file: 'Gemfile'
        )
      end

      def check_pagination
        gemfile_content = gemfile_path.read
        pagination_gems = %w[kaminari will_paginate pagy]

        return if pagination_gems.any? { |gem| gemfile_content.include?(gem) }

        add_issue(
          type: 'Performance',
          message: 'No pagination gem found - consider adding for large datasets',
          severity: :low,
          file: 'Gemfile'
        )
      end

      def check_eager_loading
        # Check controllers for potential N+1 queries
        Dir.glob(app_dir.join('controllers/**/*.rb')).each do |controller_file|
          content = File.read(controller_file)

          # Look for signs of N+1 queries
          next unless content.match?(/\.\w+\.each\s*do.*?\n.*?\.\w+\./m)

          add_issue(
            type: 'N+1 Queries',
            message: 'Potential N+1 query detected - consider using includes/eager_load',
            severity: :medium,
            file: controller_file.sub(project_root.to_s + '/', '')
          )
        end

        # Check for bootsnap
        return if gemfile_path.read.include?('bootsnap')

        add_issue(
          type: 'Boot Performance',
          message: 'Bootsnap gem not found - consider adding for faster boot times',
          severity: :low,
          file: 'Gemfile'
        )
      end
    end
  end
end
