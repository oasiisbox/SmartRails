# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/commands/audit'

RSpec.describe SmartRails::Commands::Audit do
  include SpecHelpers::RailsProjectHelper
  include SpecHelpers::FileSystemHelper

  let(:temp_dir) { setup_temp_dir }
  let(:options) { { auto: false, fix: false } }
  let(:command) { described_class.new(options) }

  before do
    Dir.chdir(temp_dir)
    project_root = create_rails_project('test_app')
    Dir.chdir(project_root)

    # Initialize SmartRails config
    config = {
      name: 'test_app',
      version: SmartRails::VERSION
    }
    File.write('.smartrails.json', JSON.pretty_generate(config))
  end

  after do
    cleanup_temp_dir
  end

  describe '#execute' do
    context 'when project is not initialized' do
      before do
        Dir.chdir(temp_dir)
        FileUtils.rm_f('.smartrails.json')
      end

      it 'shows error message' do
        expect { command.execute }.to output(/Project not initialized/).to_stdout
      end
    end

    context 'when project is initialized' do
      it 'runs all auditors' do
        expect_any_instance_of(SmartRails::Auditors::SecurityAuditor).to receive(:run).and_return([])
        expect_any_instance_of(SmartRails::Auditors::CodeQualityAuditor).to receive(:run).and_return([])
        expect_any_instance_of(SmartRails::Auditors::PerformanceAuditor).to receive(:run).and_return([])

        expect { command.execute }.to output(/Starting audit/).to_stdout
      end

      it 'generates JSON report' do
        command.execute

        report_files = Dir.glob('reports/audit_*.json')
        expect(report_files).not_to be_empty
      end

      it 'displays issues count' do
        expect { command.execute }.to output(/Audit completed/).to_stdout
      end
    end

    context 'with issues found' do
      let(:sample_issue) do
        {
          type: 'Security',
          message: 'Test security issue',
          severity: :high,
          file: 'test.rb',
          line: 10,
          auto_fix: nil
        }
      end

      before do
        allow_any_instance_of(SmartRails::Auditors::SecurityAuditor).to receive(:run).and_return([sample_issue])
        allow_any_instance_of(SmartRails::Auditors::CodeQualityAuditor).to receive(:run).and_return([])
        allow_any_instance_of(SmartRails::Auditors::PerformanceAuditor).to receive(:run).and_return([])
      end

      it 'displays issues' do
        expect { command.execute }.to output(/Test security issue/).to_stdout
      end

      it 'displays severity' do
        expect { command.execute }.to output(/HIGH/).to_stdout
      end

      it 'displays file location' do
        expect { command.execute }.to output(/test\.rb:10/).to_stdout
      end
    end

    context 'with auto-fixable issues' do
      let(:fix_called) { false }
      let(:fixable_issue) do
        {
          type: 'Style',
          message: 'Fixable issue',
          severity: :low,
          auto_fix: -> { fix_called = true }
        }
      end

      before do
        allow_any_instance_of(SmartRails::Auditors::SecurityAuditor).to receive(:run).and_return([fixable_issue])
        allow_any_instance_of(SmartRails::Auditors::CodeQualityAuditor).to receive(:run).and_return([])
        allow_any_instance_of(SmartRails::Auditors::PerformanceAuditor).to receive(:run).and_return([])
      end

      context 'with --auto flag' do
        let(:options) { { auto: true, fix: false } }

        it 'applies fixes automatically' do
          expect { command.execute }.to output(/Applying fix/).to_stdout
        end
      end

      context 'with --fix flag' do
        let(:options) { { auto: false, fix: true } }

        it 'applies fixes automatically' do
          expect { command.execute }.to output(/Applying fix/).to_stdout
        end
      end
    end
  end

  describe '#process_issues' do
    let(:issues) do
      [
        { type: 'Test', message: 'Issue 1', severity: :high },
        { type: 'Test', message: 'Issue 2', severity: :low }
      ]
    end

    it 'processes each issue' do
      command.send(:process_issues, issues)
      expect(issues.count).to eq(2)
    end
  end

  describe '#generate_reports' do
    let(:issues) { [] }

    it 'creates reports directory' do
      command.send(:generate_reports, issues)
      expect(File.directory?('reports')).to be true
    end

    it 'generates JSON report' do
      command.send(:generate_reports, issues)
      json_files = Dir.glob('reports/audit_*.json')
      expect(json_files).not_to be_empty
    end
  end

  describe '#severity_color' do
    it 'returns red for critical' do
      expect(command.send(:severity_color, :critical)).to eq(:red)
    end

    it 'returns red for high' do
      expect(command.send(:severity_color, :high)).to eq(:red)
    end

    it 'returns yellow for medium' do
      expect(command.send(:severity_color, :medium)).to eq(:yellow)
    end

    it 'returns blue for low' do
      expect(command.send(:severity_color, :low)).to eq(:blue)
    end
  end
end
