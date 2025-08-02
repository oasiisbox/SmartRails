# frozen_string_literal: true

require_relative 'base_auditor'

module SmartRails
  module Auditors
    class CodeQualityAuditor < BaseAuditor
      def run
        check_test_coverage
        check_linting_configuration
        check_code_documentation
        check_dependency_updates
        check_rails_best_practices
        check_database_indexes

        issues
      end

      private

      def check_test_coverage
        # Check for test directories
        test_dirs = %w[spec test]
        has_tests = test_dirs.any? { |dir| project_root.join(dir).exist? }

        unless has_tests
          add_issue(
            type: 'Testing',
            message: 'No test directory found (spec/ or test/)',
            severity: :high
          )
          return
        end

        # Check for test files
        test_files = Dir.glob(project_root.join('{spec,test}/**/*_{spec,test}.rb'))
        if test_files.empty?
          add_issue(
            type: 'Testing',
            message: 'No test files found',
            severity: :high
          )
        end

        # Check for SimpleCov
        gemfile_content = gemfile_path.read
        return if gemfile_content.include?('simplecov')

        add_issue(
          type: 'Test Coverage',
          message: 'SimpleCov gem not found - consider adding code coverage tracking',
          severity: :low,
          file: 'Gemfile'
        )
      end

      def check_linting_configuration
        # Check for RuboCop
        unless file_exists?('.rubocop.yml')
          add_issue(
            type: 'Code Style',
            message: 'RuboCop configuration not found',
            severity: :medium,
            auto_fix: -> { create_rubocop_config }
          )
        end

        # Check if RuboCop is in Gemfile
        return if gemfile_path.read.include?('rubocop')

        add_issue(
          type: 'Code Style',
          message: 'RuboCop gem not found in Gemfile',
          severity: :medium,
          file: 'Gemfile'
        )
      end

      def check_code_documentation
        # Check for README
        unless file_exists?('README.md', 'README.rdoc', 'README')
          add_issue(
            type: 'Documentation',
            message: 'No README file found',
            severity: :medium
          )
        end

        # Check for inline documentation in key files
        important_files = [
          'app/models/application_record.rb',
          'app/controllers/application_controller.rb'
        ]

        important_files.each do |file|
          content = read_file(file)
          next unless content

          # Simple check for comments
          comment_lines = content.lines.count { |line| line.strip.start_with?('#') }
          total_lines = content.lines.count

          next unless comment_lines.to_f / total_lines < 0.05 # Less than 5% comments

          add_issue(
            type: 'Documentation',
            message: 'Insufficient inline documentation',
            severity: :low,
            file: file
          )
        end
      end

      def check_dependency_updates
        # Check for outdated gems
        if file_exists?('Gemfile.lock')
          lockfile_mtime = File.mtime(project_root.join('Gemfile.lock'))
          days_old = (Time.now - lockfile_mtime) / 86_400

          if days_old > 90
            add_issue(
              type: 'Dependencies',
              message: 'Gemfile.lock is over 90 days old - consider updating dependencies',
              severity: :medium,
              file: 'Gemfile.lock'
            )
          end
        end

        # Check for security monitoring
        return if gemfile_path.read.include?('bundler-audit')

        add_issue(
          type: 'Dependencies',
          message: 'bundler-audit gem not found - consider adding dependency security scanning',
          severity: :medium,
          file: 'Gemfile'
        )
      end

      def check_rails_best_practices
        # Check for N+1 query detection
        unless gemfile_path.read.include?('bullet')
          add_issue(
            type: 'Performance',
            message: 'Bullet gem not found - consider adding N+1 query detection',
            severity: :low,
            file: 'Gemfile'
          )
        end

        # Check for proper migrations
        return unless project_root.join('db/migrate').exist?

        migrations = Dir.glob(project_root.join('db/migrate/*.rb'))

        migrations.each do |migration|
          content = File.read(migration)

          # Check for missing indexes on foreign keys
          next unless content.include?('references') && !content.include?('index:')

          add_issue(
            type: 'Database',
            message: 'Foreign key without index detected',
            severity: :medium,
            file: migration.sub(project_root.to_s + '/', '')
          )
        end
      end

      def check_database_indexes
        schema_file = read_file('db/schema.rb')
        return unless schema_file

        # Parse foreign keys without indexes
        foreign_keys = schema_file.scan(/t\.(?:integer|bigint|uuid)\s+"(\w+_id)"/)
        indexes = schema_file.scan(/add_index.*?"(\w+_id)"/)

        missing_indexes = foreign_keys.flatten - indexes.flatten

        missing_indexes.each do |column|
          add_issue(
            type: 'Database Performance',
            message: "Missing index on foreign key: #{column}",
            severity: :medium,
            file: 'db/schema.rb'
          )
        end
      end

      def create_rubocop_config
        config = <<~YAML
          # RuboCop configuration for Rails projects
          require:
            - rubocop-rails
            - rubocop-rspec
            - rubocop-performance

          AllCops:
            NewCops: enable
            Exclude:
              - 'db/**/*'
              - 'config/**/*'
              - 'script/**/*'
              - 'bin/**/*'
              - 'vendor/**/*'
              - 'node_modules/**/*'

          Style/Documentation:
            Enabled: false

          Style/FrozenStringLiteralComment:
            Enabled: true

          Rails:
            Enabled: true

          Metrics/BlockLength:
            Exclude:
              - 'spec/**/*'
              - 'config/routes.rb'

          Metrics/MethodLength:
            Max: 15

          Metrics/ClassLength:
            Max: 150

          Layout/LineLength:
            Max: 120
        YAML

        project_root.join('.rubocop.yml').write(config)
      end
    end
  end
end
