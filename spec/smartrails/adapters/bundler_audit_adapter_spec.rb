# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/adapters/bundler_audit_adapter'

RSpec.describe SmartRails::Adapters::BundlerAuditAdapter do
  let(:project_path) { create_temp_rails_project }
  let(:adapter) { described_class.new(project_path) }
  
  describe '#audit' do
    context 'when bundle-audit command is not available' do
      before do
        allow(adapter).to receive(:command_available?).with('bundle-audit').and_return(false)
      end
      
      it 'returns empty array' do
        expect(adapter.audit).to eq([])
      end
    end
    
    context 'when bundle-audit is available' do
      before do
        allow(adapter).to receive(:command_available?).with('bundle-audit').and_return(true)
      end
      
      context 'when no vulnerabilities found' do
        before do
          allow(adapter).to receive(:run_command).with('bundle-audit update').and_return({
            success: true,
            output: 'Updated advisory database'
          })
          allow(adapter).to receive(:run_command).with('bundle-audit check --format json').and_return({
            success: true,
            output: ''
          })
        end
        
        it 'returns empty array' do
          expect(adapter.audit).to eq([])
        end
      end
      
      context 'when vulnerabilities found with JSON output' do
        let(:json_output) do
          {
            "results" => [
              {
                "type" => "UnpatchedGem",
                "gem" => {
                  "name" => "rails",
                  "version" => "5.2.0"
                },
                "advisory" => {
                  "id" => "CVE-2022-32224",
                  "title" => "Possible RCE escalation bug with Serialized Columns in Active Record",
                  "cve" => "2022-32224",
                  "cvss_v3" => "9.8",
                  "url" => "https://github.com/advisories/GHSA-3hhc-qp5v-9p2j",
                  "criticality" => "Critical",
                  "patched_versions" => [">= 7.0.4", ">= 6.1.7", ">= 6.0.6"],
                  "unaffected_versions" => []
                }
              },
              {
                "type" => "InsecureSource",
                "source" => "http://rubygems.org/"
              }
            ]
          }.to_json
        end
        
        before do
          allow(adapter).to receive(:run_command).with('bundle-audit update').and_return({
            success: true,
            output: 'Updated'
          })
          allow(adapter).to receive(:run_command).with('bundle-audit check --format json').and_return({
            success: false, # bundle-audit returns exit code 1 when vulnerabilities found
            output: json_output
          })
        end
        
        it 'returns formatted security issues' do
          issues = adapter.audit
          
          expect(issues).to be_an(Array)
          expect(issues.size).to eq(2)
          
          # Check UnpatchedGem issue
          gem_issue = issues.find { |i| i[:metadata][:issue_type] == 'vulnerable_gem' }
          expect(gem_issue).not_to be_nil
          expect(gem_issue[:tool]).to eq(:bundleraudit)
          expect(gem_issue[:type]).to eq(:security)
          expect(gem_issue[:severity]).to eq(:critical)
          expect(gem_issue[:message]).to include('rails 5.2.0 has known vulnerability')
          expect(gem_issue[:file]).to eq('Gemfile.lock')
          expect(gem_issue[:auto_fixable]).to be true
          expect(gem_issue[:metadata][:gem_name]).to eq('rails')
          expect(gem_issue[:metadata][:cve]).to eq('2022-32224')
          expect(gem_issue[:metadata][:cvss]).to eq('9.8')
          
          # Check InsecureSource issue
          source_issue = issues.find { |i| i[:metadata][:issue_type] == 'insecure_source' }
          expect(source_issue).not_to be_nil
          expect(source_issue[:type]).to eq(:security)
          expect(source_issue[:severity]).to eq(:high)
          expect(source_issue[:message]).to include('Insecure gem source')
          expect(source_issue[:file]).to eq('Gemfile')
          expect(source_issue[:auto_fixable]).to be true
          expect(source_issue[:metadata][:source]).to eq('http://rubygems.org/')
        end
      end
      
      context 'when vulnerabilities found with text output fallback' do
        let(:text_output) do
          <<~TEXT
            Vulnerabilities found!
            
            Name: rails
            Version: 5.2.0
            Advisory: CVE-2022-32224
            Criticality: Critical
            URL: https://github.com/advisories/GHSA-3hhc-qp5v-9p2j
            Title: Possible RCE escalation bug with Serialized Columns in Active Record
            
            Name: nokogiri
            Version: 1.10.0
            Advisory: CVE-2021-30560
            Criticality: High
            URL: https://github.com/advisories/GHSA-fq42-c5rg-92c2
            Title: Update packaged libxml2
          TEXT
        end
        
        before do
          allow(adapter).to receive(:run_command).with('bundle-audit update').and_return({
            success: true,
            output: 'Updated'
          })
          allow(adapter).to receive(:run_command).with('bundle-audit check --format json').and_return({
            success: false,
            output: text_output
          })
        end
        
        it 'parses text output and returns issues' do
          issues = adapter.audit
          
          expect(issues).to be_an(Array)
          expect(issues.size).to eq(2)
          
          rails_issue = issues.find { |i| i[:metadata][:gem_name] == 'rails' }
          expect(rails_issue[:severity]).to eq(:critical)
          expect(rails_issue[:message]).to include('rails 5.2.0 has vulnerability CVE-2022-32224')
          
          nokogiri_issue = issues.find { |i| i[:metadata][:gem_name] == 'nokogiri' }
          expect(nokogiri_issue[:severity]).to eq(:critical) # High criticality maps to critical
        end
      end
      
      context 'when bundle-audit execution fails' do
        before do
          allow(adapter).to receive(:run_command).with('bundle-audit update').and_return({
            success: true,
            output: 'Updated'
          })
          allow(adapter).to receive(:run_command).with('bundle-audit check --format json').and_return({
            success: false,
            output: 'Error: bundle-audit failed to run'
          })
        end
        
        it 'returns empty array' do
          expect(adapter.audit).to eq([])
        end
      end
      
      context 'when an exception occurs' do
        before do
          allow(adapter).to receive(:run_command).and_raise(StandardError.new('Test error'))
        end
        
        it 'returns empty array and logs error' do
          expect(adapter.audit).to eq([])
        end
      end
    end
  end
  
  describe '#auto_fix' do
    let(:rails_issue) do
      {
        auto_fixable: true,
        metadata: { gem_name: 'rails', issue_type: 'vulnerable_gem' }
      }
    end
    
    let(:nokogiri_issue) do
      {
        auto_fixable: true,
        metadata: { gem_name: 'nokogiri', issue_type: 'vulnerable_gem' }
      }
    end
    
    let(:non_fixable_issue) do
      {
        auto_fixable: false,
        metadata: { gem_name: 'unfixable_gem' }
      }
    end
    
    before do
      # Create a Gemfile with direct dependencies
      File.write(File.join(project_path, 'Gemfile'), <<~RUBY)
        source 'https://rubygems.org'
        gem 'rails', '~> 5.2.0'
        gem 'nokogiri', '~> 1.10.0'
      RUBY
    end
    
    context 'with fixable issues for direct dependencies' do
      before do
        allow(adapter).to receive(:attempt_gem_update).with('rails', [rails_issue]).and_return({
          success: true,
          description: 'Updated rails to address security vulnerabilities',
          files_modified: ['Gemfile.lock'],
          gem_updated: 'rails',
          issues_addressed: 1
        })
        
        allow(adapter).to receive(:attempt_gem_update).with('nokogiri', [nokogiri_issue]).and_return({
          success: true,
          description: 'Updated nokogiri to address security vulnerabilities',
          files_modified: ['Gemfile.lock'],
          gem_updated: 'nokogiri',
          issues_addressed: 1
        })
      end
      
      it 'groups issues by gem and applies fixes' do
        fixes = adapter.auto_fix([rails_issue, nokogiri_issue])
        
        expect(fixes.size).to eq(2)
        expect(fixes.all? { |fix| fix[:success] }).to be true
        expect(fixes.map { |fix| fix[:gem_updated] }).to match_array(['rails', 'nokogiri'])
      end
    end
    
    context 'with no fixable issues' do
      it 'returns empty array' do
        fixes = adapter.auto_fix([non_fixable_issue])
        expect(fixes).to be_empty
      end
    end
  end
  
  describe 'severity mapping' do
    describe '#determine_cve_severity' do
      it 'maps CVSS scores correctly' do
        expect(adapter.send(:determine_cve_severity, { 'cvss_v3' => '9.5' })).to eq(:critical)
        expect(adapter.send(:determine_cve_severity, { 'cvss_v3' => '8.0' })).to eq(:high)
        expect(adapter.send(:determine_cve_severity, { 'cvss_v3' => '5.5' })).to eq(:medium)
        expect(adapter.send(:determine_cve_severity, { 'cvss_v3' => '2.0' })).to eq(:low)
      end
      
      it 'falls back to criticality when CVSS not available' do
        expect(adapter.send(:determine_cve_severity, { 'criticality' => 'Critical' })).to eq(:critical)
        expect(adapter.send(:determine_cve_severity, { 'criticality' => 'High' })).to eq(:critical)
        expect(adapter.send(:determine_cve_severity, { 'criticality' => 'Medium' })).to eq(:high)
        expect(adapter.send(:determine_cve_severity, { 'criticality' => 'Low' })).to eq(:medium)
      end
    end
    
    describe '#map_criticality_to_severity' do
      it 'maps criticality levels correctly' do
        expect(adapter.send(:map_criticality_to_severity, 'Critical')).to eq(:critical)
        expect(adapter.send(:map_criticality_to_severity, 'high')).to eq(:critical)
        expect(adapter.send(:map_criticality_to_severity, 'Medium')).to eq(:high)
        expect(adapter.send(:map_criticality_to_severity, 'low')).to eq(:medium)
        expect(adapter.send(:map_criticality_to_severity, nil)).to eq(:medium)
        expect(adapter.send(:map_criticality_to_severity, 'unknown')).to eq(:medium)
      end
    end
  end
  
  describe 'remediation generation' do
    describe '#generate_gem_remediation' do
      let(:gem_info) { { 'name' => 'rails', 'version' => '5.2.0' } }
      
      context 'with patched versions available' do
        let(:advisory) { { 'patched_versions' => ['>= 6.0.6', '>= 5.2.8'] } }
        
        it 'suggests updating to patched version' do
          remediation = adapter.send(:generate_gem_remediation, gem_info, advisory)
          expect(remediation).to include('Update rails to version >= 6.0.6')
        end
      end
      
      context 'with unaffected versions available' do
        let(:advisory) do
          {
            'patched_versions' => [],
            'unaffected_versions' => ['< 5.2.0', '>= 6.0.0']
          }
        end
        
        it 'suggests using unaffected version' do
          remediation = adapter.send(:generate_gem_remediation, gem_info, advisory)
          expect(remediation).to include('unaffected version')
          expect(remediation).to include('< 5.2.0, >= 6.0.0')
        end
      end
      
      context 'with no version guidance' do
        let(:advisory) { { 'patched_versions' => [], 'unaffected_versions' => [] } }
        
        it 'suggests general update' do
          remediation = adapter.send(:generate_gem_remediation, gem_info, advisory)
          expect(remediation).to include('latest version or find an alternative')
        end
      end
    end
  end
  
  describe 'auto-fix eligibility' do
    describe '#can_auto_update_gem?' do
      let(:gem_info) { { 'name' => 'rails' } }
      
      it 'returns true when patched versions available' do
        advisory = { 'patched_versions' => ['>= 6.0.6'] }
        expect(adapter.send(:can_auto_update_gem?, gem_info, advisory)).to be true
      end
      
      it 'returns false when no patched versions' do
        advisory = { 'patched_versions' => [] }
        expect(adapter.send(:can_auto_update_gem?, gem_info, advisory)).to be false
        
        advisory = { 'patched_versions' => nil }
        expect(adapter.send(:can_auto_update_gem?, gem_info, advisory)).to be false
      end
    end
  end
  
  describe 'gem update mechanism' do
    describe '#attempt_gem_update' do
      let(:issues) { [{ metadata: { gem_name: 'rails' } }] }
      
      context 'for direct dependency' do
        before do
          File.write(File.join(project_path, 'Gemfile'), <<~RUBY)
            source 'https://rubygems.org'
            gem 'rails', '~> 5.2.0'
          RUBY
        end
        
        context 'when update succeeds' do
          before do
            allow(adapter).to receive(:run_command).with('bundle update rails').and_return({
              success: true,
              output: 'Bundle updated!'
            })
          end
          
          it 'returns success result' do
            result = adapter.send(:attempt_gem_update, 'rails', issues)
            
            expect(result[:success]).to be true
            expect(result[:description]).to include('Updated rails')
            expect(result[:files_modified]).to include('Gemfile.lock')
            expect(result[:gem_updated]).to eq('rails')
            expect(result[:issues_addressed]).to eq(1)
          end
        end
        
        context 'when update fails' do
          before do
            allow(adapter).to receive(:run_command).with('bundle update rails').and_return({
              success: false,
              output: 'Update failed: version conflict'
            })
          end
          
          it 'returns failure result' do
            result = adapter.send(:attempt_gem_update, 'rails', issues)
            
            expect(result[:success]).to be false
            expect(result[:reason]).to include('Failed to update rails')
            expect(result[:suggestion]).to include('Try updating manually')
          end
        end
      end
      
      context 'for indirect dependency' do
        before do
          File.write(File.join(project_path, 'Gemfile'), <<~RUBY)
            source 'https://rubygems.org'
            gem 'other_gem'
            # rails is not directly listed
          RUBY
        end
        
        it 'returns failure for indirect dependency' do
          result = adapter.send(:attempt_gem_update, 'rails', issues)
          
          expect(result[:success]).to be false
          expect(result[:reason]).to include('indirect dependency')
          expect(result[:suggestion]).to include('Update the parent gem')
        end
      end
    end
  end
  
  describe 'text parsing edge cases' do
    describe '#parse_text_output' do
      context 'with malformed text output' do
        let(:malformed_output) do
          <<~TEXT
            Name: incomplete_gem
            Version: 1.0.0
            # Missing advisory, criticality, and URL
          TEXT
        end
        
        it 'handles incomplete gem information gracefully' do
          issues = adapter.send(:parse_text_output, malformed_output)
          expect(issues).to be_empty
        end
      end
      
      context 'with multiple complete vulnerabilities' do
        let(:complete_output) do
          <<~TEXT
            Vulnerabilities found!
            
            Name: gem1
            Version: 1.0.0
            Advisory: CVE-2021-1234
            Criticality: High
            URL: https://example.com/advisory1
            
            Name: gem2
            Version: 2.0.0
            Advisory: CVE-2021-5678
            Criticality: Medium
            URL: https://example.com/advisory2
            
            Some other text that should be ignored
          TEXT
        end
        
        it 'parses all complete vulnerabilities' do
          issues = adapter.send(:parse_text_output, complete_output)
          
          expect(issues.size).to eq(2)
          expect(issues.map { |i| i[:metadata][:gem_name] }).to match_array(['gem1', 'gem2'])
          expect(issues.map { |i| i[:metadata][:advisory_id] }).to match_array(['CVE-2021-1234', 'CVE-2021-5678'])
        end
      end
    end
  end
  
  describe 'constants and configuration' do
    it 'defines CVE severity mapping' do
      expect(described_class::CVE_SEVERITY_MAPPING).to be_a(Hash)
      expect(described_class::CVE_SEVERITY_MAPPING['high']).to eq(:critical)
      expect(described_class::CVE_SEVERITY_MAPPING['medium']).to eq(:high)
      expect(described_class::CVE_SEVERITY_MAPPING['low']).to eq(:medium)
    end
  end
  
  describe 'integration scenarios' do
    it 'handles complete audit workflow' do
      # Mock available command
      allow(adapter).to receive(:command_available?).with('bundle-audit').and_return(true)
      
      # Mock successful update and audit with vulnerabilities
      allow(adapter).to receive(:run_command).with('bundle-audit update').and_return({
        success: true,
        output: 'Updated'
      })
      
      json_output = {
        "results" => [
          {
            "type" => "UnpatchedGem",
            "gem" => { "name" => "rails", "version" => "5.2.0" },
            "advisory" => {
              "id" => "CVE-2021-1234",
              "title" => "Test vulnerability",
              "cvss_v3" => "7.5",
              "patched_versions" => [">= 6.0.0"]
            }
          }
        ]
      }.to_json
      
      allow(adapter).to receive(:run_command).with('bundle-audit check --format json').and_return({
        success: false,
        output: json_output
      })
      
      # Run audit
      issues = adapter.audit
      
      expect(issues.size).to eq(1)
      issue = issues.first
      expect(issue[:tool]).to eq(:bundleraudit)
      expect(issue[:auto_fixable]).to be true
      expect(issue[:severity]).to eq(:high)
    end
  end
end