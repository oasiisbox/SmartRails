# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/reporters/html_reporter'

RSpec.describe SmartRails::Reporters::HtmlReporter do
  include SpecHelpers::FileSystemHelper

  let(:temp_dir) { setup_temp_dir }
  let(:output_file) { File.join(temp_dir, 'report.html') }
  let(:reporter) { described_class.new }

  after do
    cleanup_temp_dir
  end

  describe '#generate' do
    context 'with no issues' do
      let(:issues) { [] }

      it 'creates HTML report file' do
        reporter.generate(issues, output_file)
        expect(File.exist?(output_file)).to be true
      end

      it 'includes HTML structure' do
        reporter.generate(issues, output_file)
        html = File.read(output_file)
        expect(html).to include('<!DOCTYPE html>')
        expect(html).to include('<html lang="en">')
        expect(html).to include('SmartRails Audit Report')
      end

      it 'includes positive summary' do
        reporter.generate(issues, output_file)
        html = File.read(output_file)
        expect(html).to include('Excellent')
        expect(html).to include('No issues found')
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
            auditor: 'PerformanceAuditor',
            auto_fix: nil
          }
        ]
      end

      it 'creates HTML report file' do
        reporter.generate(issues, output_file)
        expect(File.exist?(output_file)).to be true
      end

      it 'includes all issues' do
        reporter.generate(issues, output_file)
        html = File.read(output_file)
        expect(html).to include('CSRF protection missing')
        expect(html).to include('Missing database index')
      end

      it 'includes severity badges' do
        reporter.generate(issues, output_file)
        html = File.read(output_file)
        expect(html).to include('severity high')
        expect(html).to include('severity medium')
      end

      it 'includes file information' do
        reporter.generate(issues, output_file)
        html = File.read(output_file)
        expect(html).to include('app/controllers/application_controller.rb')
        expect(html).to include(':10')
      end

      it 'includes auditor information' do
        reporter.generate(issues, output_file)
        html = File.read(output_file)
        expect(html).to include('SecurityAuditor')
        expect(html).to include('PerformanceAuditor')
      end

      it 'marks auto-fixable issues' do
        reporter.generate(issues, output_file)
        html = File.read(output_file)
        expect(html).to include('Auto-fixable')
      end

      it 'includes CSS styles' do
        reporter.generate(issues, output_file)
        html = File.read(output_file)
        expect(html).to include('<style>')
        expect(html).to include('.container')
        expect(html).to include('.severity')
      end

      it 'includes statistics section' do
        reporter.generate(issues, output_file)
        html = File.read(output_file)
        expect(html).to include('Critical Issues')
        expect(html).to include('High Issues')
        expect(html).to include('Medium Issues')
        expect(html).to include('Low Issues')
      end

      it 'includes issues by type chart' do
        reporter.generate(issues, output_file)
        html = File.read(output_file)
        expect(html).to include('Issues by Type')
        expect(html).to include('Security')
        expect(html).to include('Performance')
      end

      it 'includes footer with version' do
        reporter.generate(issues, output_file)
        html = File.read(output_file)
        expect(html).to include('SmartRails v')
        expect(html).to include(SmartRails::VERSION)
      end
    end

    context 'with critical issues' do
      let(:issues) do
        [
          { type: 'Security', message: 'Critical vulnerability', severity: :critical, auditor: 'SecurityAuditor' }
        ]
      end

      it 'shows critical warning in summary' do
        reporter.generate(issues, output_file)
        html = File.read(output_file)
        expect(html).to include('Critical issues detected')
        expect(html).to include('immediate attention')
      end

      it 'uses critical severity class' do
        reporter.generate(issues, output_file)
        html = File.read(output_file)
        expect(html).to include('summary critical')
      end
    end
  end

  describe '#calculate_statistics' do
    let(:issues) do
      [
        { type: 'Security', severity: :critical, auto_fix: nil },
        { type: 'Security', severity: :high, auto_fix: -> {} },
        { type: 'Performance', severity: :medium, auto_fix: nil },
        { type: 'Style', severity: :low, auto_fix: nil }
      ]
    end

    it 'counts total issues' do
      stats = reporter.send(:calculate_statistics, issues)
      expect(stats[:total]).to eq(4)
    end

    it 'counts by severity' do
      stats = reporter.send(:calculate_statistics, issues)
      expect(stats[:critical]).to eq(1)
      expect(stats[:high]).to eq(1)
      expect(stats[:medium]).to eq(1)
      expect(stats[:low]).to eq(1)
    end

    it 'counts auto-fixable issues' do
      stats = reporter.send(:calculate_statistics, issues)
      expect(stats[:auto_fixable]).to eq(1)
    end

    it 'groups by type' do
      stats = reporter.send(:calculate_statistics, issues)
      expect(stats[:by_type]['Security']).to eq(2)
      expect(stats[:by_type]['Performance']).to eq(1)
      expect(stats[:by_type]['Style']).to eq(1)
    end
  end

  describe '#severity_weight' do
    it 'orders critical first' do
      expect(reporter.send(:severity_weight, :critical)).to be < reporter.send(:severity_weight, :high)
    end

    it 'orders high before medium' do
      expect(reporter.send(:severity_weight, :high)).to be < reporter.send(:severity_weight, :medium)
    end

    it 'orders medium before low' do
      expect(reporter.send(:severity_weight, :medium)).to be < reporter.send(:severity_weight, :low)
    end
  end
end
