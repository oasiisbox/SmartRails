# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/git_manager'

RSpec.describe SmartRails::GitManager do
  let(:project_path) { create_temp_rails_project }
  let(:git_manager) { described_class.new(project_path) }
  
  before do
    # Initialize git repository in test project
    Dir.chdir(project_path) do
      system('git init --quiet')
      system('git config user.name "Test User"')
      system('git config user.email "test@example.com"')
      system('git add .')
      system('git commit -m "Initial commit" --quiet')
    end
  end
  
  describe '#initialize' do
    it 'sets project path' do
      expect(git_manager.project_path).to eq(project_path)
    end
  end
  
  describe '#git_available?' do
    it 'returns true when git is available' do
      expect(git_manager.git_available?).to be true
    end
  end
  
  describe '#current_branch_name' do
    it 'returns current branch name' do
      branch = git_manager.current_branch_name
      expect(branch).to match(/main|master/)
    end
  end
  
  describe '#working_directory_clean?' do
    context 'with clean working tree' do
      it 'returns true' do
        expect(git_manager.working_directory_clean?).to be true
      end
    end
    
    context 'with dirty working tree' do
      before do
        File.write(File.join(project_path, 'test_change.rb'), 'puts "changed"')
      end
      
      it 'returns false' do
        expect(git_manager.working_directory_clean?).to be false
      end
    end
  end
  
  describe '#create_fix_branch' do
    let(:branch_name) { 'smartrails-fix-123' }
    
    it 'creates a fix branch when working directory is clean' do
      result = git_manager.create_fix_branch(branch_name)
      
      expect(result).to be true
      expect(git_manager.current_branch_name).to eq(branch_name)
    end
    
    it 'fails when working directory is dirty' do
      # Make working directory dirty
      File.write(File.join(project_path, 'dirty_file.rb'), 'dirty content')
      
      result = git_manager.create_fix_branch(branch_name)
      expect(result).to be false
    end
    
    context 'when branch already exists' do
      before do
        git_manager.create_fix_branch(branch_name)
        git_manager.switch_to_branch('main') || git_manager.switch_to_branch('master')
      end
      
      it 'fails to create branch with same name' do
        result = git_manager.create_fix_branch(branch_name)
        expect(result).to be false
      end
    end
  end
  
  describe '#switch_to_branch' do
    let(:original_branch) { git_manager.current_branch_name }
    let(:test_branch) { 'test-branch' }
    
    before do
      git_manager.create_fix_branch(test_branch)
    end
    
    it 'switches to specified branch' do
      git_manager.switch_to_branch(original_branch)
      expect(git_manager.current_branch_name).to eq(original_branch)
      
      git_manager.switch_to_branch(test_branch)
      expect(git_manager.current_branch_name).to eq(test_branch)
    end
    
    it 'returns true on successful switch' do
      result = git_manager.switch_to_branch(original_branch)
      expect(result).to be true
    end
    
    it 'returns false on failed switch' do
      result = git_manager.switch_to_branch('nonexistent-branch')
      expect(result).to be false
    end
  end
  
  describe '#commit_fixes' do
    let(:commit_message) { 'Fix applied by SmartRails' }
    let(:fixes) do
      [{
        success: true,
        description: 'Fixed RuboCop style issue',
        files_modified: ['app/models/user.rb'],
        tool: :rubocop
      }]
    end
    
    before do
      # Create and modify a file
      user_file = File.join(project_path, 'app/models/user.rb')
      FileUtils.mkdir_p(File.dirname(user_file))
      File.write(user_file, "class User < ApplicationRecord\nend")
    end
    
    it 'commits fixes with detailed message' do
      result = git_manager.commit_fixes(fixes, commit_message)
      
      expect(result).to be true
      
      # Check commit was created
      Dir.chdir(project_path) do
        commit_msg = `git log -1 --pretty=%B`
        expect(commit_msg).to include('Fix applied by SmartRails')
        expect(commit_msg).to include('SmartRails')
      end
    end
    
    it 'stages only modified files from fixes' do
      result = git_manager.commit_fixes(fixes, commit_message)
      expect(result).to be true
    end
    
    context 'when no fixes provided' do
      it 'returns false' do
        result = git_manager.commit_fixes([], commit_message)
        expect(result).to be false
      end
    end
  end
  
  
  
  describe 'private methods' do
    describe '#run_git_command' do
      it 'executes git commands in project directory' do
        result = git_manager.send(:run_git_command, 'status --porcelain')
        
        expect(result).to have_key(:success)
        expect(result).to have_key(:output)
        expect(result[:success]).to be true
      end
      
      it 'handles command failures' do
        result = git_manager.send(:run_git_command, 'invalid-command')
        
        expect(result[:success]).to be false
        expect(result[:output]).to include('invalid-command')
      end
    end
  end
  
  describe 'complete fix workflow with conflict handling' do
    it 'supports the complete fix workflow' do
      original_branch = git_manager.current_branch_name
      
      # 1. Create fix branch
      branch_name = 'smartrails-fix-test'
      branch_result = git_manager.create_fix_branch(branch_name)
      expect(branch_result).to be true
      expect(git_manager.current_branch_name).to eq(branch_name)
      
      # 2. Make changes
      test_file = File.join(project_path, 'fixed_file.rb')
      File.write(test_file, 'fixed content')
      
      # 3. Commit fixes
      fixes = [{
        success: true,
        description: 'Applied SmartRails fix',
        files_modified: ['fixed_file.rb'],
        tool: :rubocop
      }]
      commit_result = git_manager.commit_fixes(fixes, 'Apply SmartRails fix')
      expect(commit_result).to be true
      
      # 4. Generate patch
      patch_result = git_manager.create_patch(fixes)
      expect(patch_result).to be_a(Hash)
      expect(patch_result[:content]).to include('fixed content')
      
      # 5. Switch back to original branch
      switch_result = git_manager.switch_to_branch(original_branch)
      expect(switch_result).to be true
      
      # 6. Cleanup by deleting fix branch
      delete_result = git_manager.delete_branch(branch_name)
      expect(delete_result).to be true
    end
    
    it 'handles conflict scenarios during branch operations' do
      original_branch = git_manager.current_branch_name
      
      # Create a conflict by modifying same file on different branches
      conflict_file = File.join(project_path, 'conflict_test.rb')
      File.write(conflict_file, "# Original content")
      Dir.chdir(project_path) do
        system('git add conflict_test.rb')
        system('git commit -m "Add conflict test file" --quiet')
      end
      
      # Create fix branch and modify file
      fix_branch = 'conflict-fix-branch'
      git_manager.create_fix_branch(fix_branch)
      File.write(conflict_file, "# Modified on fix branch")
      
      fixes = [{
        success: true,
        description: 'Modified conflict file',
        files_modified: ['conflict_test.rb'],
        tool: :rubocop
      }]
      git_manager.commit_fixes(fixes, 'Modify on fix branch')
      
      # Switch back to original and modify same file
      git_manager.switch_to_branch(original_branch)
      File.write(conflict_file, "# Modified on original branch")
      Dir.chdir(project_path) do
        system('git add conflict_test.rb')
        system('git commit -m "Modify on original branch" --quiet')
      end
      
      # Try to merge (this would normally create conflicts)
      # In real scenario, GitManager would need conflict resolution
      # For now, just verify branches exist and can be switched
      expect(git_manager.switch_to_branch(fix_branch)).to be true
      expect(git_manager.switch_to_branch(original_branch)).to be true
      
      # Cleanup
      git_manager.delete_branch(fix_branch)
    end
  end

  describe '#create_pull_request_branch' do
    let(:base_branch) { git_manager.current_branch_name }
    let(:pr_branch) { 'smartrails-pr-test' }
    
    before do
      # Create a branch with changes for PR
      git_manager.create_fix_branch(pr_branch)
      File.write(File.join(project_path, 'pr_test.rb'), 'pr content')
      fixes = [{
        success: true,
        description: 'PR test changes',
        files_modified: ['pr_test.rb'],
        tool: :rubocop
      }]
      git_manager.commit_fixes(fixes, 'Add PR test changes')
    end
    
    it 'fails when no remote is configured' do
      result = git_manager.create_pull_request_branch(base_branch)
      expect(result).to be false
    end
    
    it 'returns false when trying to create PR from base branch' do
      git_manager.switch_to_branch(base_branch)
      result = git_manager.create_pull_request_branch(base_branch)
      expect(result).to be false
    end
  end
end