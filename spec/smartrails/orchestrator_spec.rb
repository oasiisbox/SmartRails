# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/orchestrator'

RSpec.describe SmartRails::Orchestrator do
  let(:project_path) { create_temp_rails_project }
  let(:options) { {} }
  let(:orchestrator) { described_class.new(project_path, options) }
  
  describe '#initialize' do
    it 'sets project path and options' do
      expect(orchestrator.project_path).to eq(project_path)
      expect(orchestrator.options).to eq(options)
    end
    
    it 'initializes results with metadata' do
      expect(orchestrator.results).to have_key(:phases)
      expect(orchestrator.results).to have_key(:metadata)
      expect(orchestrator.results[:phases]).to eq([])
    end
    
    it 'detects available tools' do
      expect(orchestrator.instance_variable_get(:@available_tools)).to be_a(Hash)
    end
  end
  
  describe '#run' do
    context 'with default options' do
      it 'runs audit pipeline phases' do
        results = orchestrator.run
        
        expect(results).to have_key(:phases)
        expect(results).to have_key(:duration_ms)
        expect(results).to have_key(:summary)
        expect(results).to have_key(:score)
      end
      
      it 'tracks execution time' do
        results = orchestrator.run
        
        expect(results[:duration_ms]).to be_a(Numeric)
        expect(results[:duration_ms]).to be > 0
      end
    end
    
    context 'when critical issues are found' do
      before do
        # Mock critical security issue
        allow(orchestrator).to receive(:run_phase).and_return({
          phase: :security_critical,
          issues: [{ severity: :critical, message: 'Critical vulnerability' }],
          tool_results: {}
        })
        
        allow(orchestrator).to receive(:has_critical_issues?).and_return(true)
      end
      
      it 'stops early on critical issues when configured' do
        results = orchestrator.run
        
        expect(results[:stopped_early]).to be true
        expect(results[:stop_reason]).to include('Critical issues found')
      end
    end
    
    context 'with phase filtering' do
      let(:options) { { only: [:security] } }
      
      it 'runs only specified phases' do
        allow(orchestrator).to receive(:should_run_phase?) do |phase|
          phase[:phase] == :security_critical
        end
        
        results = orchestrator.run
        expect(results[:phases].size).to be <= 1
      end
    end
    
    context 'with skip option' do
      let(:options) { { skip: [:database] } }
      
      it 'skips specified phases' do
        allow(orchestrator).to receive(:should_run_phase?) do |phase|
          phase[:phase] != :database
        end
        
        results = orchestrator.run
        phases_run = results[:phases].map { |p| p[:phase] }
        expect(phases_run).not_to include(:database)
      end
    end
  end
  
  describe '#detect_available_tools' do
    it 'detects installed gems' do
      tools = orchestrator.send(:detect_available_tools)
      
      expect(tools).to be_a(Hash)
      expect(tools).to have_key(:brakeman)
      expect(tools).to have_key(:rubocop)
      expect(tools).to have_key(:bundler_audit)
    end
    
    it 'checks for command availability' do
      allow(orchestrator).to receive(:command_available?).with('bundle-audit').and_return(true)
      
      tools = orchestrator.send(:detect_available_tools)
      expect(tools[:bundler_audit]).to be_truthy
    end
  end
  
  describe '#should_run_phase?' do
    context 'with only option' do
      let(:options) { { only: [:security] } }
      
      it 'returns true for security phase' do
        phase = { phase: :security_critical }
        expect(orchestrator.send(:should_run_phase?, phase)).to be true
      end
      
      it 'returns false for non-security phase' do
        phase = { phase: :quality }
        expect(orchestrator.send(:should_run_phase?, phase)).to be false
      end
    end
    
    context 'with skip option' do
      let(:options) { { skip: [:database] } }
      
      it 'returns false for skipped phase' do
        phase = { phase: :database }
        expect(orchestrator.send(:should_run_phase?, phase)).to be false
      end
      
      it 'returns true for non-skipped phase' do
        phase = { phase: :security_critical }
        expect(orchestrator.send(:should_run_phase?, phase)).to be true
      end
    end
  end
  
  describe '#run_phase' do
    let(:phase_config) do
      {
        phase: :security_critical,
        name: 'Security Critical',
        tools: [:brakeman],
        parallel: false
      }
    end
    
    before do
      allow(orchestrator).to receive(:run_tool).and_return({
        issues: [],
        duration_ms: 100
      })
    end
    
    it 'runs tools in the phase' do
      result = orchestrator.send(:run_phase, phase_config)
      
      expect(result).to have_key(:phase)
      expect(result).to have_key(:name)
      expect(result).to have_key(:tool_results)
      expect(result[:phase]).to eq(:security_critical)
    end
    
    context 'with parallel execution' do
      let(:phase_config) do
        {
          phase: :quality,
          name: 'Code Quality',
          tools: [:rubocop, :rails_best_practices],
          parallel: true
        }
      end
      
      it 'runs tools in parallel when configured' do
        expect(Parallel).to receive(:map).and_call_original
        orchestrator.send(:run_phase, phase_config)
      end
    end
    
    context 'with sequential execution' do
      it 'runs tools sequentially when parallel is false' do
        expect(Parallel).not_to receive(:map)
        orchestrator.send(:run_phase, phase_config)
      end
    end
  end
  
  describe '#generate_summary' do
    before do
      orchestrator.instance_variable_set(:@results, {
        phases: [
          {
            phase: :security_critical,
            tool_results: {
              brakeman: { issues: [{ severity: :critical }, { severity: :high }] }
            }
          },
          {
            phase: :quality,
            tool_results: {
              rubocop: { issues: [{ severity: :medium }, { severity: :low }] }
            }
          }
        ]
      })
    end
    
    it 'generates issue summary by severity' do
      summary = orchestrator.send(:generate_summary)
      
      expect(summary).to have_key(:total_issues)
      expect(summary).to have_key(:by_severity)
      expect(summary[:total_issues]).to eq(4)
      expect(summary[:by_severity][:critical]).to eq(1)
      expect(summary[:by_severity][:high]).to eq(1)
      expect(summary[:by_severity][:medium]).to eq(1)
      expect(summary[:by_severity][:low]).to eq(1)
    end
    
    it 'generates phase summary' do
      summary = orchestrator.send(:generate_summary)
      
      expect(summary).to have_key(:by_phase)
      expect(summary[:by_phase][:security_critical]).to eq(2)
      expect(summary[:by_phase][:quality]).to eq(2)
    end
  end
  
  describe '#calculate_scores' do
    before do
      orchestrator.instance_variable_set(:@results, {
        phases: [
          {
            phase: :security_critical,
            tool_results: {
              brakeman: { 
                issues: [{ severity: :critical }],
                score: 60
              }
            }
          },
          {
            phase: :quality,
            tool_results: {
              rubocop: {
                issues: [{ severity: :low }],
                score: 85
              }
            }
          }
        ]
      })
    end
    
    it 'calculates overall score' do
      scores = orchestrator.send(:calculate_scores)
      
      expect(scores).to have_key(:overall)
      expect(scores[:overall]).to be_a(Numeric)
      expect(scores[:overall]).to be_between(0, 100)
    end
    
    it 'calculates phase scores' do
      scores = orchestrator.send(:calculate_scores)
      
      expect(scores).to have_key(:by_phase)
      expect(scores[:by_phase][:security_critical]).to be_a(Numeric)
      expect(scores[:by_phase][:quality]).to be_a(Numeric)
    end
    
    it 'calculates severity-weighted score' do
      scores = orchestrator.send(:calculate_scores)
      
      # Critical issues should heavily impact score
      expect(scores[:overall]).to be < 70
    end
  end
  
  describe '#has_critical_issues?' do
    context 'with critical issues' do
      let(:phase_results) do
        {
          tool_results: {
            brakeman: { issues: [{ severity: :critical }] }
          }
        }
      end
      
      it 'returns true' do
        expect(orchestrator.send(:has_critical_issues?, phase_results)).to be true
      end
    end
    
    context 'without critical issues' do
      let(:phase_results) do
        {
          tool_results: {
            rubocop: { issues: [{ severity: :low }] }
          }
        }
      end
      
      it 'returns false' do
        expect(orchestrator.send(:has_critical_issues?, phase_results)).to be false
      end
    end
  end
  
  describe 'AUDIT_PIPELINE constant' do
    it 'defines all audit phases' do
      expect(described_class::AUDIT_PIPELINE).to be_an(Array)
      expect(described_class::AUDIT_PIPELINE).not_to be_empty
    end
    
    it 'has required keys for each phase' do
      described_class::AUDIT_PIPELINE.each do |phase|
        expect(phase).to have_key(:phase)
        expect(phase).to have_key(:name)
        expect(phase).to have_key(:tools)
        expect(phase).to have_key(:parallel)
        expect(phase).to have_key(:stop_on_critical)
      end
    end
    
    it 'includes critical security phase first' do
      first_phase = described_class::AUDIT_PIPELINE.first
      expect(first_phase[:phase]).to eq(:security_critical)
      expect(first_phase[:stop_on_critical]).to be true
    end
  end
  
  describe 'integration with adapters' do
    it 'can run with actual adapters' do
      # This is an integration test that would run actual adapters
      # In a real test suite, you might want to mock these
      allow(orchestrator).to receive(:gem_available?).and_return(false)
      allow(orchestrator).to receive(:command_available?).and_return(false)
      
      results = orchestrator.run
      expect(results).to be_a(Hash)
      expect(results[:phases]).to be_an(Array)
    end
  end
end