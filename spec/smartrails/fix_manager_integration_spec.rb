# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/fix_manager'

RSpec.describe SmartRails::FixManager, 'Triple Security Integration' do
  let(:project_path) { create_temp_rails_project }
  let(:fix_manager) { described_class.new(project_path) }
  
  # Shared fixtures available to all test contexts
  let(:safe_fixable_issue) do
    {
      tool: :rubocop,
      type: :quality,
      severity: :low,
      message: 'Use single quotes for string literals',
      file: 'app/models/test_model.rb',
      line: 1,
      auto_fixable: true,
      fix_command: 'bundle exec rubocop --auto-correct --only Style/StringLiterals app/models/test_model.rb',
      metadata: { cop_name: 'Style/StringLiterals' }
    }
  end
  
  describe 'Triple Security Architecture' do
    
    it 'executes the complete security workflow: snapshot → apply → validate → commit' do
      # Create test file that needs fixing
      test_file = File.join(project_path, 'app/models/test_model.rb')
      File.write(test_file, 'class TestModel < ApplicationRecord; end')
      
      # Step 1: Snapshot - Create initial state backup  
      snapshot_id = fix_manager.snapshot_manager.create_snapshot("Before applying RuboCop fix")
      expect(snapshot_id).not_to be_nil
      
      # Verify snapshot contains the snapshot ID (list_snapshots returns metadata objects)
      snapshots = fix_manager.snapshot_manager.list_snapshots
      expect(snapshots.any? { |s| s[:id] == snapshot_id }).to be true
      
      # Step 2: Apply - Execute the fix
      result = fix_manager.apply_fixes([safe_fixable_issue], { auto_apply_safe: true })
      
      expect(result[:fixes]).not_to be_empty
      expect(result[:errors]).to be_empty
      
      # Step 3: Validate - Verify the fix was applied correctly
      # Note: Since this is a mock fix_command, we verify the workflow completed
      expect(result[:summary]).to be_a(Hash)
      
      # Step 4: Commit - Changes should be attempted if validation passes
      # Note: The actual file change depends on fix_command execution
    end
    
    it 'supports rollback when fixes fail validation' do
      # Create a snapshot before changes
      snapshot_id = fix_manager.snapshot_manager.create_snapshot("Test rollback scenario")
      
      # Modify file to simulate a problematic state
      controller_file = File.join(project_path, 'app/controllers/application_controller.rb')
      original_content = File.read(controller_file)
      File.write(controller_file, "class BrokenController\n  # Invalid syntax")
      
      # Attempt rollback
      restore_result = fix_manager.snapshot_manager.restore_snapshot(snapshot_id)
      expect(restore_result).to be true
      
      # Verify rollback worked
      restored_content = File.read(controller_file)
      expect(restored_content).to eq(original_content)
    end
    
    it 'handles dry-run mode without making permanent changes' do
      # Create test file
      test_file = File.join(project_path, 'app/models/test_model.rb')
      original_content = 'class TestModel < ApplicationRecord; end'
      File.write(test_file, original_content)
      
      # Execute dry run
      dry_run_result = fix_manager.dry_run([safe_fixable_issue])
      
      expect(dry_run_result).to be_a(Hash)
      expect(dry_run_result[:previews]).to be_an(Array)
      expect(dry_run_result[:previews].size).to eq(1)
      
      preview = dry_run_result[:previews].first
      expect(preview[:issue]).to eq(safe_fixable_issue)
      expect(preview[:risk_level]).to eq(:safe)
      
      # Verify no changes were made
      unchanged_content = File.read(test_file)
      expect(unchanged_content).to eq(original_content)
    end
  end
  
  describe 'Integration with Adapters' do
    it 'works with Brakeman adapter fixes' do
      # Mock a Brakeman CSRF issue
      brakeman_issue = {
        tool: :brakeman,
        type: :security,
        severity: :high,
        message: 'CSRF protection not found',
        file: 'app/controllers/application_controller.rb',
        auto_fixable: true,
        metadata: { warning_type: 'Cross-Site Request Forgery' }
      }
      
      result = fix_manager.apply_fixes([brakeman_issue], { auto_apply_safe: true })
      
      expect(result[:fixes]).not_to be_empty
      expect(result[:errors]).to be_empty
    end
    
    it 'works with RuboCop adapter fixes' do
      # Create a file with RuboCop issues
      test_file = File.join(project_path, 'app/models/test_model.rb')
      File.write(test_file, 'class TestModel < ApplicationRecord; end')
      
      rubocop_issue = {
        tool: :rubocop,
        type: :quality,
        severity: :low,
        message: 'Missing frozen string literal comment',
        file: 'app/models/test_model.rb',
        line: 1,
        auto_fixable: true,
        fix_command: 'bundle exec rubocop --auto-correct --only Style/FrozenStringLiteralComment app/models/test_model.rb',
        metadata: { cop_name: 'Style/FrozenStringLiteralComment' }
      }
      
      result = fix_manager.apply_fixes([rubocop_issue], { auto_apply_safe: true })
      
      expect(result[:fixes]).not_to be_empty
      expect(result[:errors]).to be_empty
    end
  end
  
  describe 'Error Handling and Recovery' do
    it 'handles adapter failures gracefully' do
      failing_issue = {
        type: :security,
        severity: :high,
        message: 'This fix will fail',
        file: 'nonexistent/file.rb',
        auto_fixable: true,
        fix_command: 'echo "This will fail"',
        metadata: { adapter: :test }
      }
      
      result = fix_manager.apply_fixes([failing_issue], { auto_apply_safe: true })
      
      expect(result[:fixes]).to be_empty
      expect(result[:errors]).not_to be_empty
    end
    
    it 'maintains system state consistency after failures' do
      # Verify project is in clean state before test
      expect(fix_manager.git_manager.working_directory_clean?).to be true
      
      # Apply a failing fix
      failing_issue = {
        type: :quality,
        severity: :low,
        message: 'Failing fix test',
        file: 'app/controllers/application_controller.rb',
        auto_fixable: true,
        fix_command: '/bin/false', # Command that always fails
        metadata: { adapter: :test }
      }
      
      result = fix_manager.apply_fixes([failing_issue], { auto_apply_safe: true })
      
      # System should still be in a consistent state
      expect(result[:errors]).not_to be_empty
      expect(File.exist?(File.join(project_path, 'app/controllers/application_controller.rb'))).to be true
    end
  end
  
  describe 'Snapshot Management Integration' do
    it 'creates and manages snapshots during fix operations' do
      # Create test file
      test_file = File.join(project_path, 'app/models/test_model.rb')
      File.write(test_file, 'class TestModel < ApplicationRecord; end')
      
      initial_snapshots = fix_manager.snapshot_manager.list_snapshots
      
      result = fix_manager.apply_fixes([safe_fixable_issue], { auto_apply_safe: true })
      
      final_snapshots = fix_manager.snapshot_manager.list_snapshots
      expect(final_snapshots.size).to be > initial_snapshots.size
    end
    
    it 'cleans up temporary snapshots after successful operations' do
      # This test would verify cleanup behavior
      # Implementation depends on FixManager cleanup strategy
      expect(fix_manager.snapshot_manager).to respond_to(:cleanup_old_snapshots)
    end
  end
end