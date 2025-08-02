# frozen_string_literal: true

require_relative 'base_auditor'

module SmartRails
  module Auditors
    class SecurityAuditor < BaseAuditor
      def run
        return issues unless rails_app?

        check_csrf_protection
        check_force_ssl
        check_secure_headers
        check_strong_parameters
        check_sql_injection_risks
        check_secrets_management
        check_authentication
        check_authorization

        issues
      end

      private

      def check_csrf_protection
        app_controller = read_file('app/controllers/application_controller.rb')
        return unless app_controller

        return if app_controller.include?('protect_from_forgery')

        add_issue(
          type: 'CSRF Protection',
          message: 'CSRF protection is not enabled in ApplicationController',
          severity: :high,
          file: 'app/controllers/application_controller.rb',
          auto_fix: -> { fix_csrf_protection }
        )
      end

      def check_force_ssl
        production_rb = read_file('config/environments/production.rb')
        return unless production_rb

        return if production_rb.include?('config.force_ssl = true')

        add_issue(
          type: 'SSL Configuration',
          message: 'Force SSL is not enabled in production',
          severity: :high,
          file: 'config/environments/production.rb',
          auto_fix: -> { fix_force_ssl }
        )
      end

      def check_secure_headers
        return if gemfile_path.read.include?('secure_headers')

        add_issue(
          type: 'Security Headers',
          message: 'secure_headers gem is not installed',
          severity: :medium,
          file: 'Gemfile'
        )
      end

      def check_strong_parameters
        Dir.glob(app_dir.join('controllers/**/*.rb')).each do |controller_file|
          content = File.read(controller_file)

          # Check for params.permit usage
          next unless content.include?('params[') && !content.include?('params.require')

          add_issue(
            type: 'Strong Parameters',
            message: 'Potential mass assignment vulnerability - use strong parameters',
            severity: :high,
            file: controller_file.sub(project_root.to_s + '/', '')
          )
        end
      end

      def check_sql_injection_risks
        Dir.glob(app_dir.join('**/*.rb')).each do |file|
          content = File.read(file)

          # Check for dangerous SQL patterns
          dangerous_patterns = [
            /where\s*\(\s*["'].*#\{/,
            /find_by_sql\s*\(\s*["'].*#\{/,
            /execute\s*\(\s*["'].*#\{/
          ]

          dangerous_patterns.each do |pattern|
            next unless content.match?(pattern)

            add_issue(
              type: 'SQL Injection',
              message: 'Potential SQL injection vulnerability detected',
              severity: :critical,
              file: file.sub(project_root.to_s + '/', '')
            )
          end
        end
      end

      def check_secrets_management
        # Check for hardcoded secrets
        files_to_check = [
          'config/database.yml',
          'config/secrets.yml',
          'config/application.rb'
        ]

        files_to_check.each do |file|
          content = read_file(file)
          next unless content

          next unless content.match?(/password:\s*["'][^"']+["']/) ||
                      content.match?(/secret_key_base:\s*["'][^"']+["']/)

          add_issue(
            type: 'Secrets Management',
            message: 'Hardcoded secrets detected - use environment variables',
            severity: :critical,
            file: file
          )
        end

        # Check for credentials.yml.enc
        return if file_exists?('config/credentials.yml.enc', 'config/master.key')

        add_issue(
          type: 'Secrets Management',
          message: 'Rails credentials not properly configured',
          severity: :high
        )
      end

      def check_authentication
        # Check for devise or other auth gems
        gemfile_content = gemfile_path.read
        auth_gems = %w[devise authlogic clearance sorcery]

        return if auth_gems.any? { |gem| gemfile_content.include?(gem) }

        add_issue(
          type: 'Authentication',
          message: 'No authentication gem detected - consider adding authentication',
          severity: :medium,
          file: 'Gemfile'
        )
      end

      def check_authorization
        # Check for authorization gems
        gemfile_content = gemfile_path.read
        auth_gems = %w[pundit cancancan]

        return if auth_gems.any? { |gem| gemfile_content.include?(gem) }

        add_issue(
          type: 'Authorization',
          message: 'No authorization gem detected - consider adding authorization',
          severity: :medium,
          file: 'Gemfile'
        )
      end

      def fix_csrf_protection
        file_path = project_root.join('app/controllers/application_controller.rb')
        content = file_path.read

        # Add protect_from_forgery after class definition
        content.sub!(/class ApplicationController.*?\n/m) do |match|
          match + "  protect_from_forgery with: :exception\n"
        end

        file_path.write(content)
      end

      def fix_force_ssl
        file_path = project_root.join('config/environments/production.rb')
        content = file_path.read

        # Add force_ssl configuration
        content.sub!(/Rails\.application\.configure do.*?\n/m) do |match|
          match + "  config.force_ssl = true\n"
        end

        file_path.write(content)
      end
    end
  end
end
