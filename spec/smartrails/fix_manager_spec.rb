# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/fix_manager'
require 'smartrails/snapshot_manager'
require 'smartrails/git_manager'

RSpec.describe SmartRails::FixManager do
  let(:project_path) { create_temp_rails_project }
  let(:fix_manager) { described_class.new(project_path) }
  let(:mock_snapshot_manager) { instance_double(SmartRails::SnapshotManager) }
  let(:mock_git_manager) { instance_double(SmartRails::GitManager) }
  let(:mock_prompt) { instance_double(TTY::Prompt) }
  
  before do
    allow(SmartRails::SnapshotManager).to receive(:new).and_return(mock_snapshot_manager)
    allow(SmartRails::GitManager).to receive(:new).and_return(mock_git_manager)
    allow(TTY::Prompt).to receive(:new).and_return(mock_prompt)
  end
  
  describe '#initialize' do
    it 'sets up project path and dependencies' do
      expect(fix_manager.project_path).to eq(project_path)
      expect(fix_manager.snapshot_manager).to eq(mock_snapshot_manager)
      expect(fix_manager.git_manager).to eq(mock_git_manager) 
      expect(fix_manager.prompt).to eq(mock_prompt)
    end
  end
  
  describe '#apply_fixes' do
    let(:safe_issue) do
      {
        auto_fixable: true,
        severity: :low,
        type: 'Style/StringLiterals',
        file: 'app/models/user.rb',
        auto_fix: proc { 'Fixed string literals' }
      }
    end
    
    let(:risky_issue) do
      {
        auto_fixable: true,
        severity: :high,
        type: 'Security/Mass Assignment',
        file: 'app/controllers/users_controller.rb',
        auto_fix: proc { 'Fixed mass assignment' }
      }
    end
    
    let(:non_fixable_issue) do
      {
        auto_fixable: false,
        severity: :medium,
        type: 'Manual Review Required'
      }
    end
    
    context 'with empty issues array' do
      it 'returns empty result' do
        result = fix_manager.apply_fixes([])
        
        expect(result[:fixes]).to be_empty
        expect(result[:errors]).to be_empty
      end
    end
    
    context 'with no auto-fixable issues' do
      it 'returns message about no fixable issues' do
        result = fix_manager.apply_fixes([non_fixable_issue])
        
        expect(result[:fixes]).to be_empty
        expect(result[:errors]).to be_empty
        expect(result[:message]).to include('No auto-fixable issues found')
      end
    end
    
    context 'with safe fixes and auto_apply_safe option' do
      before do
        allow(fix_manager).to receive(:categorize_fixes).and_return([[safe_issue], []])
        allow(fix_manager).to receive(:apply_fix_batch).and_return({
          fixes: [{ success: true, issue: safe_issue }],
          errors: []
        })
        allow(fix_manager).to receive(:generate_fixes_report)
      end
      
      it 'applies safe fixes automatically' do
        result = fix_manager.apply_fixes([safe_issue], auto_apply_safe: true)
        
        expect(result[:fixes]).to have(1).item
        expect(result[:errors]).to be_empty
        expect(result[:summary][:successful]).to eq(1)
      end
    end
    
    context 'with user confirmation for safe fixes' do
      before do
        allow(fix_manager).to receive(:categorize_fixes).and_return([[safe_issue], []])
        allow(fix_manager).to receive(:confirm_safe_fixes).and_return(true)
        allow(fix_manager).to receive(:apply_fix_batch).and_return({
          fixes: [{ success: true, issue: safe_issue }],
          errors: []
        })
        allow(fix_manager).to receive(:generate_fixes_report)
      end
      
      it 'applies safe fixes after confirmation' do
        result = fix_manager.apply_fixes([safe_issue])
        
        expect(fix_manager).to have_received(:confirm_safe_fixes).with([safe_issue])
        expect(result[:fixes]).to have(1).item
      end
    end
    
    context 'with risky fixes' do
      before do
        allow(fix_manager).to receive(:categorize_fixes).and_return([[], [risky_issue]])
        allow(fix_manager).to receive(:confirm_risky_fix).and_return(true)
        allow(fix_manager).to receive(:apply_single_fix).and_return({ success: true, issue: risky_issue })
        allow(fix_manager).to receive(:generate_fixes_report)
      end
      
      it 'asks for individual confirmation for risky fixes' do
        result = fix_manager.apply_fixes([risky_issue])
        
        expect(fix_manager).to have_received(:confirm_risky_fix).with(risky_issue)
        expect(result[:fixes]).to have(1).item
      end
    end
    
    context 'when user declines risky fix' do
      before do
        allow(fix_manager).to receive(:categorize_fixes).and_return([[], [risky_issue]])
        allow(fix_manager).to receive(:confirm_risky_fix).and_return(false)
        allow(fix_manager).to receive(:generate_fixes_report)
      end
      
      it 'skips declined risky fixes' do
        result = fix_manager.apply_fixes([risky_issue])
        
        expect(result[:fixes]).to be_empty
        expect(result[:summary][:total_attempted]).to eq(1)
        expect(result[:summary][:successful]).to eq(0)
      end
    end
  end
  
  describe '#dry_run' do
    let(:fixable_issue) do
      {
        auto_fixable: true,
        type: 'Style/StringLiterals',
        file: 'app/models/user.rb',
        line: 5,
        message: 'Use single quotes'
      }
    end
    
    before do
      allow(fix_manager).to receive(:generate_dry_run_preview).and_return({
        issue: fixable_issue,
        preview: 'Would change double quotes to single quotes',
        estimated_changes: 1,
        risk_level: :safe
      })
    end
    
    it 'generates dry run previews for auto-fixable issues' do
      result = fix_manager.dry_run([fixable_issue, non_fixable_issue])
      
      expect(result).to have(1).item
      expect(result.first[:issue]).to eq(fixable_issue)
      expect(result.first[:preview]).to include('Would change')
    end
  end
  
  describe '#rollback_fix' do
    let(:fix_id) { 'fix_12345' }
    
    context 'when rollback succeeds' do
      before do
        allow(mock_snapshot_manager).to receive(:restore).with(fix_id).and_return(true)
        allow(mock_git_manager).to receive(:rollback_commit).with(fix_id).and_return(true)
      end
      
      it 'rolls back using snapshot manager and git manager' do
        result = fix_manager.rollback_fix(fix_id)
        
        expect(result[:success]).to be true
        expect(result[:method]).to eq('snapshot + git')
        expect(mock_snapshot_manager).to have_received(:restore).with(fix_id)
      end
    end
    
    context 'when snapshot rollback fails but git succeeds' do
      before do
        allow(mock_snapshot_manager).to receive(:restore).with(fix_id).and_return(false)
        allow(mock_git_manager).to receive(:rollback_commit).with(fix_id).and_return(true)
      end
      
      it 'falls back to git rollback' do
        result = fix_manager.rollback_fix(fix_id)
        
        expect(result[:success]).to be true
        expect(result[:method]).to eq('git_only')
      end
    end
    
    context 'when both rollback methods fail' do
      before do
        allow(mock_snapshot_manager).to receive(:restore).with(fix_id).and_return(false)
        allow(mock_git_manager).to receive(:rollback_commit).with(fix_id).and_return(false)
      end
      
      it 'returns failure' do
        result = fix_manager.rollback_fix(fix_id)
        
        expect(result[:success]).to be false
        expect(result[:reason]).to include('failed')
      end
    end
  end
  
  describe '#list_snapshots' do
    let(:snapshots) do
      [
        { id: 'snap_1', timestamp: Time.now - 3600, description: 'Before CSRF fix' },
        { id: 'snap_2', timestamp: Time.now - 1800, description: 'Before RuboCop fixes' }
      ]
    end
    
    before do
      allow(mock_snapshot_manager).to receive(:list_snapshots).and_return(snapshots)
    end
    
    it 'returns list of available snapshots' do
      result = fix_manager.list_snapshots
      
      expect(result).to eq(snapshots)
      expect(mock_snapshot_manager).to have_received(:list_snapshots)
    end
  end
  
  describe 'private methods' do
    describe '#categorize_fixes' do
      let(:safe_issue) { { severity: :low, type: 'Style/StringLiterals' } }
      let(:medium_issue) { { severity: :medium, type: 'Layout/IndentationConsistency' } }
      let(:risky_issue) { { severity: :high, type: 'Security/MassAssignment' } }
      
      it 'categorizes fixes by risk level' do
        safe_fixes, risky_fixes = fix_manager.send(:categorize_fixes, [safe_issue, medium_issue, risky_issue])
        
        expect(safe_fixes).to include(safe_issue, medium_issue)
        expect(risky_fixes).to include(risky_issue)
      end
    end
    
    describe '#apply_single_fix' do
      let(:issue) do
        {
          type: 'Style/StringLiterals',
          file: 'app/models/user.rb',
          auto_fix: proc { 'Fixed!' }
        }
      end
      
      context 'when fix is successful' do
        before do
          allow(mock_snapshot_manager).to receive(:create_snapshot).and_return('snapshot_123')
          allow(mock_git_manager).to receive(:create_temp_branch).and_return('fix_branch_123')
          allow(fix_manager).to receive(:execute_auto_fix).and_return({ success: true })
          allow(fix_manager).to receive(:validate_fix).and_return(true)
          allow(mock_git_manager).to receive(:commit_changes)
        end
        
        it 'creates snapshot, applies fix, and commits' do
          result = fix_manager.send(:apply_single_fix, issue, { risk_level: :safe })
          
          expect(result[:success]).to be true
          expect(mock_snapshot_manager).to have_received(:create_snapshot)
          expect(mock_git_manager).to have_received(:create_temp_branch)
          expect(mock_git_manager).to have_received(:commit_changes)
        end
      end
      
      context 'when fix fails' do
        before do
          allow(mock_snapshot_manager).to receive(:create_snapshot).and_return('snapshot_123')
          allow(mock_git_manager).to receive(:create_temp_branch).and_return('fix_branch_123')
          allow(fix_manager).to receive(:execute_auto_fix).and_raise(StandardError.new('Fix failed'))
          allow(mock_snapshot_manager).to receive(:restore).and_return(true)
          allow(mock_git_manager).to receive(:cleanup_temp_branch)
        end
        
        it 'rolls back on failure' do
          result = fix_manager.send(:apply_single_fix, issue, { risk_level: :safe })
          
          expect(result[:success]).to be false
          expect(result[:error]).to include('Fix failed')
          expect(mock_snapshot_manager).to have_received(:restore)
          expect(mock_git_manager).to have_received(:cleanup_temp_branch)
        end
      end
    end
    
    describe '#generate_dry_run_preview' do
      let(:issue) do
        {
          type: 'Style/StringLiterals',
          file: 'app/models/user.rb',
          line: 5,
          message: 'Use single quotes for string literals',
          severity: :low
        }
      end
      
      it 'generates preview of what fix would do' do
        preview = fix_manager.send(:generate_dry_run_preview, issue)
        
        expect(preview[:issue]).to eq(issue)
        expect(preview[:preview]).to be_a(String)
        expect(preview[:risk_level]).to eq(:safe)
        expect(preview[:estimated_changes]).to be_a(Integer)
      end
    end
    
    describe '#confirm_safe_fixes' do
      let(:safe_fixes) { [{ type: 'Style/StringLiterals' }, { type: 'Layout/TrailingWhitespace' }] }
      
      before do
        allow(mock_prompt).to receive(:yes?).and_return(true)
      end
      
      it 'prompts user for confirmation of safe fixes' do
        result = fix_manager.send(:confirm_safe_fixes, safe_fixes)
        
        expect(result).to be true
        expect(mock_prompt).to have_received(:yes?).with(/Apply 2 safe fixes/)
      end
    end
    
    describe '#confirm_risky_fix' do
      let(:risky_issue) do
        {
          type: 'Security/MassAssignment',
          severity: :high,
          file: 'app/controllers/users_controller.rb',
          message: 'Potential mass assignment vulnerability'
        }
      end
      
      before do
        allow(mock_prompt).to receive(:yes?).and_return(false)
      end
      
      it 'prompts user for confirmation of risky fix' do
        result = fix_manager.send(:confirm_risky_fix, risky_issue)
        
        expect(result).to be false
        expect(mock_prompt).to have_received(:yes?).with(/Apply risky fix.*Security\/MassAssignment/m)
      end
    end
  end
  
  describe 'fix execution flow' do
    let(:issue) do
      {
        auto_fixable: true,
        severity: :low,
        type: 'Style/StringLiterals',
        file: 'app/models/user.rb',
        auto_fix: proc { 'Fixed string literals' }
      }
    end
    
    it 'follows the triple security pattern: snapshot -> apply -> validate -> commit' do
      allow(fix_manager).to receive(:categorize_fixes).and_return([[issue], []])
      allow(fix_manager).to receive(:confirm_safe_fixes).and_return(true)
      
      # Mock the triple security flow
      allow(mock_snapshot_manager).to receive(:create_snapshot).and_return('snapshot_123')
      allow(mock_git_manager).to receive(:create_temp_branch).and_return('branch_123')
      allow(fix_manager).to receive(:execute_auto_fix).and_return({ success: true })
      allow(fix_manager).to receive(:validate_fix).and_return(true)
      allow(mock_git_manager).to receive(:commit_changes)
      allow(fix_manager).to receive(:generate_fixes_report)
      
      # Execute fix
      fix_manager.apply_fixes([issue])
      
      # Verify triple security pattern was followed
      expect(mock_snapshot_manager).to have_received(:create_snapshot)
      expect(mock_git_manager).to have_received(:create_temp_branch)
      expect(mock_git_manager).to have_received(:commit_changes)
    end
  end
end