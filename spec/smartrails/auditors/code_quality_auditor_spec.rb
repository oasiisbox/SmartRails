# frozen_string_literal: true

RSpec.describe SmartRails::Auditors::CodeQualityAuditor do
  let(:project_root) { create_temp_rails_project }
  let(:auditor) { described_class.new(project_root) }
  let(:application_record_path) { File.join(project_root, 'app', 'models', 'application_record.rb') }
  let(:application_controller_path) { File.join(project_root, 'app', 'controllers', 'application_controller.rb') }

  before do
    File.write(
      application_controller_path,
      <<~RUBY
        # Base controller documentation
        class ApplicationController < ActionController::Base
          # Provided by Rails.
        end
      RUBY
    )
  end

  describe '#check_code_documentation' do
    it 'reports insufficient inline documentation when ratio is below the threshold' do
      File.write(
        application_record_path,
        <<~RUBY
          class ApplicationRecord < ActiveRecord::Base
            def useful_method
              do_something
            end
          end
        RUBY
      )

      auditor.send(:check_code_documentation)

      issue = expect_issue(
        auditor.issues,
        type: 'Documentation',
        severity: :low,
        file: 'app/models/application_record.rb'
      )
      expected_percentage = (described_class::INLINE_DOCUMENTATION_THRESHOLD * 100).to_i
      expect(issue[:message]).to include("#{expected_percentage}%")
    end

    it 'ignores files without executable lines when computing the documentation ratio' do
      File.write(
        application_record_path,
        <<~RUBY
          # Only comments

          # and blank lines
        RUBY
      )

      auditor.send(:check_code_documentation)

      expect_no_issue(auditor.issues, type: 'Documentation')
    end

    it 'does not penalise files that include documentation but many blank lines' do
      content = "# Documented method\n" + ("\n" * 100) + <<~RUBY
        class ApplicationRecord < ActiveRecord::Base
          def useful_method
            do_something
          end
        end
      RUBY

      File.write(application_record_path, content)

      auditor.send(:check_code_documentation)

      expect_no_issue(auditor.issues, type: 'Documentation')
    end
  end
end
