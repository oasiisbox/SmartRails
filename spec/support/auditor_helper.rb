# frozen_string_literal: true

module SpecHelpers
  module AuditorHelper
    def expect_issue(issues, type:, severity: nil, file: nil)
      matching_issues = issues.select { |issue| issue[:type] == type }

      expect(matching_issues).not_to be_empty,
                                     "Expected to find issue of type '#{type}', but found: #{issues.map { |i| i[:type] }}"

      issue = matching_issues.first

      if severity
        expect(issue[:severity]).to eq(severity),
                                    "Expected issue severity to be #{severity}, but was #{issue[:severity]}"
      end

      if file
        expect(issue[:file]).to include(file),
                                "Expected issue file to include '#{file}', but was '#{issue[:file]}'"
      end

      issue
    end

    def expect_no_issue(issues, type:)
      matching_issues = issues.select { |issue| issue[:type] == type }

      expect(matching_issues).to be_empty,
                                 "Expected no issues of type '#{type}', but found: #{matching_issues}"
    end

    def mock_rails_project(project_root)
      allow(File).to receive(:exist?).with("#{project_root}/Gemfile").and_return(true)
      allow(File).to receive(:exist?).with("#{project_root}/config/application.rb").and_return(true)
      allow(Dir).to receive(:exist?).with("#{project_root}/app").and_return(true)
    end

    def create_vulnerable_controller
      <<~RUBY
        class UsersController < ApplicationController
          def create
            @user = User.new(params[:user])
            if @user.save
              redirect_to @user
            else
              render :new
            end
          end

          def search
            @users = User.where("name = '\#{params[:name]}'")
          end
        end
      RUBY
    end

    def create_secure_controller
      <<~RUBY
        class UsersController < ApplicationController
          protect_from_forgery with: :exception
        #{'  '}
          def create
            @user = User.new(user_params)
            if @user.save
              redirect_to @user
            else
              render :new
            end
          end

          def search
            @users = User.where(name: params[:name])
          end
        #{'  '}
          private
        #{'  '}
          def user_params
            params.require(:user).permit(:name, :email)
          end
        end
      RUBY
    end
  end
end
