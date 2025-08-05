# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/adapters/rubocop_adapter'

RSpec.describe SmartRails::Adapters::RubocopAdapter do
  let(:project_path) { create_temp_rails_project }
  let(:adapter) { described_class.new(project_path) }
  
  describe '#audit' do
    context 'when RuboCop gem is not available' do
      before do
        allow(adapter).to receive(:gem_available?).with('rubocop').and_return(false)
      end
      
      it 'returns empty array' do
        expect(adapter.audit).to eq([])
      end
    end
    
    context 'when RuboCop gem is available' do
      before do
        allow(adapter).to receive(:gem_available?).with('rubocop').and_return(true)
        allow(adapter).to receive(:require).with('rubocop')
      end
      
      context 'when RuboCop command fails' do
        before do
          allow(adapter).to receive(:run_command).and_return({
            success: false,
            output: 'RuboCop command failed',
            exit_code: 1
          })
        end
        
        it 'returns empty array' do
          expect(adapter.audit).to eq([])
        end
      end
      
      context 'when RuboCop runs successfully' do
        let(:rubocop_output) do
          {
            success: false, # RuboCop returns non-zero exit code when offenses found
            output: json_output,
            exit_code: 1
          }
        end
        
        let(:json_output) do
          {
            "files" => [
              {
                "path" => "#{project_path}/app/controllers/users_controller.rb",
                "offenses" => [
                  {
                    "severity" => "error",
                    "message" => "Missing frozen string literal comment",
                    "cop_name" => "Style/FrozenStringLiteralComment",
                    "correctable" => true,
                    "location" => {
                      "line" => 1,
                      "column" => 1,
                      "length" => 5
                    }
                  },
                  {
                    "severity" => "convention",
                    "message" => "Use single quotes for string literals",
                    "cop_name" => "Style/StringLiterals",
                    "correctable" => true,
                    "location" => {
                      "line" => 5,
                      "column" => 10,
                      "length" => 12
                    }
                  }
                ]
              }
            ]
          }.to_json
        end
        
        before do
          allow(adapter).to receive(:run_command).and_return(rubocop_output)
        end
        
        it 'returns formatted issues' do
          issues = adapter.audit
          
          expect(issues).to be_an(Array)
          expect(issues.size).to eq(2)
          
          first_issue = issues.first
          expect(first_issue[:tool]).to eq(:rubocop)
          expect(first_issue[:type]).to eq(:quality)
          expect(first_issue[:severity]).to eq(:high)
          expect(first_issue[:message]).to eq('Missing frozen string literal comment')
          expect(first_issue[:file]).to eq('app/controllers/users_controller.rb')
          expect(first_issue[:line]).to eq(1)
          expect(first_issue[:column]).to eq(1)
          expect(first_issue[:metadata][:cop_name]).to eq('Style/FrozenStringLiteralComment')
          expect(first_issue[:metadata][:correctable]).to be true
          
          second_issue = issues.second
          expect(second_issue[:severity]).to eq(:low)
          expect(second_issue[:auto_fixable]).to be true # StringLiterals is in AUTO_FIXABLE_COPS
        end
      end
      
      context 'when RuboCop output is invalid JSON' do
        before do
          allow(adapter).to receive(:run_command).and_return({
            success: false,
            output: 'invalid json output',
            exit_code: 1
          })
        end
        
        it 'returns empty array' do
          expect(adapter.audit).to eq([])
        end
      end
    end
  end
  
  describe '#auto_fix' do
    let(:fixable_issue) do
      {
        auto_fixable: true,
        file: 'app/controllers/users_controller.rb',
        metadata: { cop_name: 'Style/StringLiterals' }
      }
    end
    
    let(:non_fixable_issue) do
      {
        auto_fixable: false,
        file: 'app/controllers/users_controller.rb',
        metadata: { cop_name: 'Metrics/MethodLength' }
      }
    end
    
    context 'with auto-fixable issues' do
      before do
        allow(adapter).to receive(:run_rubocop_autocorrect).and_return({ success: true })
      end
      
      it 'applies fixes to auto-fixable issues' do
        fixes = adapter.auto_fix([fixable_issue, non_fixable_issue])
        
        expect(fixes.size).to eq(1)
        expect(fixes.first[:success]).to be true
      end
    end
    
    context 'with no auto-fixable issues' do
      it 'returns empty array' do
        fixes = adapter.auto_fix([non_fixable_issue])
        
        expect(fixes).to be_empty
      end
    end
    
    context 'with empty issues array' do
      it 'returns empty array' do
        fixes = adapter.auto_fix([])
        
        expect(fixes).to be_empty
      end
    end
  end
  
  describe '#severity_mapping' do
    it 'maps RuboCop severities correctly' do
      expect(described_class::SEVERITY_MAPPING['error']).to eq(:high)
      expect(described_class::SEVERITY_MAPPING['warning']).to eq(:medium)
      expect(described_class::SEVERITY_MAPPING['convention']).to eq(:low)
      expect(described_class::SEVERITY_MAPPING['refactor']).to eq(:low)
      expect(described_class::SEVERITY_MAPPING['info']).to eq(:low)
    end
  end
  
  describe 'private methods' do
    describe '#determine_category' do
      it 'categorizes cops correctly' do
        expect(adapter.send(:determine_category, 'Style/StringLiterals')).to eq(:style)
        expect(adapter.send(:determine_category, 'Layout/IndentationConsistency')).to eq(:layout)
        expect(adapter.send(:determine_category, 'Rails/HttpPositionalArguments')).to eq(:rails)
        expect(adapter.send(:determine_category, 'Metrics/MethodLength')).to eq(:metrics)
        expect(adapter.send(:determine_category, 'Security/Eval')).to eq(:security)
        expect(adapter.send(:determine_category, 'Performance/RegexpMatch')).to eq(:performance)
        expect(adapter.send(:determine_category, 'UnknownCop')).to eq(:general)
      end
    end
    
    describe '#generate_remediation' do
      let(:offense) do
        {
          'cop_name' => 'Style/StringLiterals',
          'message' => 'Use single quotes for string literals'
        }
      end
      
      it 'generates remediation text' do
        remediation = adapter.send(:generate_remediation, offense)
        
        expect(remediation).to include('Style/StringLiterals')
        expect(remediation).to include('Use single quotes')
      end
    end
    
    describe '#generate_fix_command' do
      let(:offense) do
        {
          'cop_name' => 'Style/StringLiterals',
          'correctable' => true
        }
      end
      
      it 'generates fix command for correctable offense' do
        command = adapter.send(:generate_fix_command, offense, 'app/models/user.rb')
        
        expect(command).to include('rubocop')
        expect(command).to include('--autocorrect')
        expect(command).to include('Style/StringLiterals')
        expect(command).to include('app/models/user.rb')
      end
      
      it 'returns nil for non-correctable offense' do
        offense['correctable'] = false
        command = adapter.send(:generate_fix_command, offense, 'app/models/user.rb')
        
        expect(command).to be_nil
      end
    end
    
    describe '#generate_doc_url' do
      it 'generates correct documentation URLs' do
        url = adapter.send(:generate_doc_url, 'Style/StringLiterals')
        expect(url).to include('rubocop.org')
        expect(url).to include('Style/StringLiterals')
        
        url = adapter.send(:generate_doc_url, 'Rails/HttpPositionalArguments')
        expect(url).to include('rubocop-rails')
        expect(url).to include('Rails/HttpPositionalArguments')
      end
    end
    
    describe '#run_rubocop_autocorrect' do
      let(:file_path) { 'app/controllers/users_controller.rb' }
      let(:cop_names) { ['Style/StringLiterals', 'Layout/TrailingWhitespace'] }
      
      context 'when autocorrect succeeds' do
        before do
          allow(adapter).to receive(:run_command).and_return({
            success: true,
            output: 'Inspecting 1 file\n.\n\n1 file inspected, 2 offenses detected, 2 offenses corrected',
            exit_code: 0
          })
        end
        
        it 'returns success result' do
          result = adapter.send(:run_rubocop_autocorrect, file_path, cop_names)
          
          expect(result[:success]).to be true
          expect(result[:description]).to include('RuboCop autocorrect')
          expect(result[:files_modified]).to include(file_path)
          expect(result[:cops_applied]).to eq(cop_names)
        end
      end
      
      context 'when autocorrect fails' do
        before do
          allow(adapter).to receive(:run_command).and_return({
            success: false,
            output: 'RuboCop failed to run',
            exit_code: 1
          })
        end
        
        it 'returns failure result' do
          result = adapter.send(:run_rubocop_autocorrect, file_path, cop_names)
          
          expect(result[:success]).to be false
          expect(result[:reason]).to include('RuboCop autocorrect failed')
        end
      end
    end
  end
  
  describe 'constants' do
    it 'defines severity mapping' do
      expect(described_class::SEVERITY_MAPPING).to be_a(Hash)
      expect(described_class::SEVERITY_MAPPING).to have_key('error')
      expect(described_class::SEVERITY_MAPPING).to have_key('warning')
    end
    
    it 'defines auto-fixable cops' do
      expect(described_class::AUTO_FIXABLE_COPS).to be_an(Array)
      expect(described_class::AUTO_FIXABLE_COPS).to include('Style/StringLiterals')
      expect(described_class::AUTO_FIXABLE_COPS).to include('Layout/TrailingWhitespace')
    end
  end
end