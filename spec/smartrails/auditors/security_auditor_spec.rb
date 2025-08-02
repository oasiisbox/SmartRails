# frozen_string_literal: true

RSpec.describe SmartRails::Auditors::SecurityAuditor do
  let(:project_root) { create_temp_rails_project }
  let(:auditor) { described_class.new(project_root) }

  describe '#run' do
    context 'when checking CSRF protection' do
      it 'detects missing CSRF protection in ApplicationController' do
        create_rails_controller(project_root, 'application', <<~RUBY)
          class ApplicationController < ActionController::Base
            # No protect_from_forgery
          end
        RUBY

        issues = auditor.run

        expect_issue(issues,
                     type: 'CSRF Protection',
                     severity: :high,
                     file: 'application_controller.rb')
      end

      it 'passes when CSRF protection is enabled' do
        create_rails_controller(project_root, 'application', <<~RUBY)
          class ApplicationController < ActionController::Base
            protect_from_forgery with: :exception
          end
        RUBY

        issues = auditor.run

        expect_no_issue(issues, type: 'CSRF Protection')
      end
    end

    context 'when checking for SQL injection vulnerabilities' do
      it 'detects potential SQL injection in controllers' do
        create_rails_controller(project_root, 'users', <<~RUBY)
          class UsersController < ApplicationController
            def search
              @users = User.where("name = '\#{params[:name]}'")
            end
          end
        RUBY

        issues = auditor.run

        expect_issue(issues,
                     type: 'SQL Injection Risk',
                     severity: :critical,
                     file: 'users_controller.rb')
      end

      it 'passes when using safe parameterized queries' do
        create_rails_controller(project_root, 'users', <<~RUBY)
          class UsersController < ApplicationController
            def search
              @users = User.where(name: params[:name])
            end
          end
        RUBY

        issues = auditor.run

        expect_no_issue(issues, type: 'SQL Injection Risk')
      end
    end

    context 'when checking for hardcoded secrets' do
      it 'detects hardcoded API keys in code' do
        create_rails_controller(project_root, 'api', <<~RUBY)
          class ApiController < ApplicationController
            API_KEY = "sk-1234567890abcdef"
            SECRET_TOKEN = "abc123def456"
          #{'  '}
            def authenticate
              # Using hardcoded secrets
            end
          end
        RUBY

        issues = auditor.run

        expect_issue(issues,
                     type: 'Hardcoded Secret',
                     severity: :critical,
                     file: 'api_controller.rb')
      end

      it 'passes when using environment variables' do
        create_rails_controller(project_root, 'api', <<~RUBY)
          class ApiController < ApplicationController
            def authenticate
              api_key = ENV['API_KEY']
              secret = Rails.application.credentials.secret_token
            end
          end
        RUBY

        issues = auditor.run

        expect_no_issue(issues, type: 'Hardcoded Secret')
      end
    end

    context 'when checking Strong Parameters' do
      it 'detects missing strong parameters' do
        create_rails_controller(project_root, 'users', <<~RUBY)
          class UsersController < ApplicationController
            def create
              @user = User.new(params[:user])
            end
          end
        RUBY

        issues = auditor.run

        expect_issue(issues,
                     type: 'Missing Strong Parameters',
                     severity: :high,
                     file: 'users_controller.rb')
      end

      it 'passes when strong parameters are used' do
        create_rails_controller(project_root, 'users', <<~RUBY)
          class UsersController < ApplicationController
            def create
              @user = User.new(user_params)
            end
          #{'  '}
            private
          #{'  '}
            def user_params
              params.require(:user).permit(:name, :email)
            end
          end
        RUBY

        issues = auditor.run

        expect_no_issue(issues, type: 'Missing Strong Parameters')
      end
    end

    context 'when checking SSL configuration' do
      it 'detects missing force_ssl configuration' do
        create_config_file(project_root, 'environments/production.rb', <<~RUBY)
          Rails.application.configure do
            config.cache_classes = true
            # No force_ssl configuration
          end
        RUBY

        issues = auditor.run

        expect_issue(issues,
                     type: 'SSL Configuration',
                     severity: :medium,
                     file: 'production.rb')
      end

      it 'passes when force_ssl is enabled' do
        create_config_file(project_root, 'environments/production.rb', <<~RUBY)
          Rails.application.configure do
            config.force_ssl = true
          end
        RUBY

        issues = auditor.run

        expect_no_issue(issues, type: 'SSL Configuration')
      end
    end
  end

  describe '#auto_fix' do
    it 'can automatically fix CSRF protection' do
      controller_file = create_rails_controller(project_root, 'application', <<~RUBY)
        class ApplicationController < ActionController::Base
        end
      RUBY

      issues = auditor.run
      csrf_issue = expect_issue(issues, type: 'CSRF Protection')

      expect(csrf_issue[:auto_fixable]).to be true

      # Apply auto-fix
      csrf_issue[:auto_fix].call

      # Verify fix was applied
      content = File.read(controller_file)
      expect(content).to include('protect_from_forgery')
    end
  end
end
