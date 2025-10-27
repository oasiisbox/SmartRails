# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/reporters/json_reporter'

RSpec.describe SmartRails::Reporters::JsonReporter do
  include SpecHelpers::FileSystemHelper

  let(:temp_dir) { setup_temp_dir }
  let(:output_file) { File.join(temp_dir, 'report.json') }
  let(:reporter) { described_class.new }

  after do
    cleanup_temp_dir
  end

  describe '#generate' do
    context 'with no issues' do
      let(:issues) { [] }

      it 'creates JSON report file' do
        reporter.generate(issues, output_file)
        expect(File.exist?(output_file)).to be true
      end

      it 'includes positive summary' do
        reporter.generate(issues, output_file)
        report = JSON.parse(File.read(output_file))
        expect(report['summary']).to include('No issues found')
      end

      it 'includes zero statistics' do
        reporter.generate(issues, output_file)
        report = JSON.parse(File.read(output_file))
        expect(report['statistics']['total']).to eq(0)
      end
    end

    context 'with issues' do
      let(:issues) do
        [
          {
            type: 'Security',
            message: 'CSRF protection missing',
            severity: :high,
            file: 'app/controllers/application_controller.rb',
            line: 10,
            auditor: 'SecurityAuditor',
            auto_fix: -> {}
          },
          {
            type: 'Performance',
            message: 'Missing database index',
            severity: :medium,
            file: 'db/schema.rb',
            line: nil,
            auditor: 'PerformanceAuditor',
            auto_fix: nil
          },
          {
            type: 'Code Quality',
            message: 'Missing tests',
            severity: :low,
            file: nil,
            line: nil,
            auditor: 'CodeQualityAuditor',
            auto_fix: nil
          }
        ]
      end

      it 'creates JSON report file' do
        reporter.generate(issues, output_file)
        expect(File.exist?(output_file)).to be true
      end

      it 'includes timestamp' do
        reporter.generate(issues, output_file)
        report = JSON.parse(File.read(output_file))
        expect(report['timestamp']).not_to be_nil
        expect(report['timestamp']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      end

      it 'includes version' do
        reporter.generate(issues, output_file)
        report = JSON.parse(File.read(output_file))
        expect(report['version']).to eq(SmartRails::VERSION)
      end

      it 'includes summary' do
        reporter.generate(issues, output_file)
        report = JSON.parse(File.read(output_file))
        expect(report['summary']).to include('high severity')
      end

      it 'includes correct statistics' do
        reporter.generate(issues, output_file)
        report = JSON.parse(File.read(output_file))

        stats = report['statistics']
        expect(stats['total']).to eq(3)
        expect(stats['by_severity']['high']).to eq(1)
        expect(stats['by_severity']['medium']).to eq(1)
        expect(stats['by_severity']['low']).to eq(1)
        expect(stats['auto_fixable']).to eq(1)
      end

      it 'includes formatted issues' do
        reporter.generate(issues, output_file)
        report = JSON.parse(File.read(output_file))

        expect(report['issues'].count).to eq(3)

        first_issue = report['issues'][0]
        expect(first_issue['type']).to eq('Security')
        expect(first_issue['message']).to eq('CSRF protection missing')
        expect(first_issue['severity']).to eq('high')
        expect(first_issue['file']).to eq('app/controllers/application_controller.rb')
        expect(first_issue['line']).to eq(10)
        expect(first_issue['auditor']).to eq('SecurityAuditor')
        expect(first_issue['auto_fixable']).to be true
      end

      it 'handles issues without file' do
        reporter.generate(issues, output_file)
        report = JSON.parse(File.read(output_file))

        last_issue = report['issues'][2]
        expect(last_issue['file']).to be_nil
        expect(last_issue['line']).to be_nil
      end

      it 'handles issues without auto_fix' do
        reporter.generate(issues, output_file)
        report = JSON.parse(File.read(output_file))

        second_issue = report['issues'][1]
        expect(second_issue['auto_fixable']).to be false
      end
    end

    context 'with critical issues' do
      let(:issues) do
        [
          { type: 'Security', message: 'Critical issue', severity: :critical, auditor: 'SecurityAuditor' }
        ]
      end

      it 'includes critical in summary' do
        reporter.generate(issues, output_file)
        report = JSON.parse(File.read(output_file))
        expect(report['summary']).to include('critical')
        expect(report['summary']).to include('immediate attention')
      end
    end

    context 'with only low severity issues' do
      let(:issues) do
        [
          { type: 'Style', message: 'Minor issue', severity: :low, auditor: 'CodeQualityAuditor' }
        ]
      end

      it 'includes appropriate summary' do
        reporter.generate(issues, output_file)
        report = JSON.parse(File.read(output_file))
        expect(report['summary']).to include('minor')
        expect(report['summary']).to include('over time')
      end
    end
  end

  describe '#generate_statistics' do
    let(:issues) do
      [
        { type: 'Security', message: 'Issue 1', severity: :high, auditor: 'SecurityAuditor', auto_fix: -> {} },
        { type: 'Security', message: 'Issue 2', severity: :medium, auditor: 'SecurityAuditor', auto_fix: nil },
        { type: 'Performance', message: 'Issue 3', severity: :low, auditor: 'PerformanceAuditor', auto_fix: nil }
      ]
    end

    it 'groups issues by severity' do
      stats = reporter.send(:generate_statistics, issues)
      expect(stats[:by_severity][:high]).to eq(1)
      expect(stats[:by_severity][:medium]).to eq(1)
      expect(stats[:by_severity][:low]).to eq(1)
    end

    it 'groups issues by type' do
      stats = reporter.send(:generate_statistics, issues)
      expect(stats[:by_type]['Security']).to eq(2)
      expect(stats[:by_type]['Performance']).to eq(1)
    end

    it 'groups issues by auditor' do
      stats = reporter.send(:generate_statistics, issues)
      expect(stats[:by_auditor]['SecurityAuditor']).to eq(2)
      expect(stats[:by_auditor]['PerformanceAuditor']).to eq(1)
    end

    it 'counts auto-fixable issues' do
      stats = reporter.send(:generate_statistics, issues)
      expect(stats[:auto_fixable]).to eq(1)
    end
  end
end
