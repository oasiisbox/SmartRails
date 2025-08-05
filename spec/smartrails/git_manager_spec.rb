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
    
    it 'initializes temp branches tracking' do
      expect(git_manager.instance_variable_get(:@temp_branches)).to eq([])
    end
  end
  
  describe '#git_available?' do
    it 'returns true when git is available' do
      expect(git_manager.git_available?).to be true
    end
  end
  
  describe '#current_branch' do
    it 'returns current branch name' do
      branch = git_manager.current_branch
      expect(branch).to match(/main|master/)
    end
  end
  
  describe '#clean_working_tree?' do
    context 'with clean working tree' do
      it 'returns true' do
        expect(git_manager.clean_working_tree?).to be true
      end
    end
    
    context 'with dirty working tree' do
      before do
        File.write(File.join(project_path, 'test_change.rb'), 'puts "changed"')
      end
      
      it 'returns false' do
        expect(git_manager.clean_working_tree?).to be false
      end
    end
  end
  
  describe '#create_temp_branch' do
    let(:branch_name) { 'smartrails-fix-123' }
    
    it 'creates a temporary branch' do
      result = git_manager.create_temp_branch(branch_name)
      
      expect(result).to eq(branch_name)
      expect(git_manager.current_branch).to eq(branch_name)
    end
    
    it 'tracks temporary branches' do
      git_manager.create_temp_branch(branch_name)
      
      temp_branches = git_manager.instance_variable_get(:@temp_branches)
      expect(temp_branches).to include(branch_name)
    end
    
    context 'when branch already exists' do
      before do
        Dir.chdir(project_path) { system("git checkout -b #{branch_name} --quiet") }
        Dir.chdir(project_path) { system("git checkout main --quiet 2>/dev/null || git checkout master --quiet") }
      end
      
      it 'creates a unique branch name' do
        result = git_manager.create_temp_branch(branch_name)
        
        expect(result).to start_with(branch_name)
        expect(result).not_to eq(branch_name)
      end
    end
  end
  
  describe '#switch_to_branch' do
    let(:original_branch) { git_manager.current_branch }
    let(:temp_branch) { 'test-branch' }
    
    before do
      git_manager.create_temp_branch(temp_branch)
    end
    
    it 'switches to specified branch' do
      git_manager.switch_to_branch(original_branch)
      expect(git_manager.current_branch).to eq(original_branch)
      
      git_manager.switch_to_branch(temp_branch)
      expect(git_manager.current_branch).to eq(temp_branch)
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
  
  describe '#commit_changes' do
    let(:commit_message) { 'Fix applied by SmartRails' }
    let(:files) { ['app/models/user.rb'] }
    
    before do
      # Create and modify a file
      user_file = File.join(project_path, 'app/models/user.rb')
      FileUtils.mkdir_p(File.dirname(user_file))
      File.write(user_file, "class User < ApplicationRecord\nend")
    end
    
    it 'commits specified files with message' do
      result = git_manager.commit_changes(commit_message, files)
      
      expect(result[:success]).to be true
      expect(result[:commit_sha]).to be_a(String)
      expect(result[:commit_sha].length).to eq(40) # Full SHA length
    end
    
    it 'includes fix metadata in commit' do
      metadata = { fix_type: 'security', tool: 'brakeman' }
      result = git_manager.commit_changes(commit_message, files, metadata)
      
      expect(result[:success]).to be true
      
      # Check commit message includes metadata
      Dir.chdir(project_path) do
        commit_msg = `git log -1 --pretty=%B`
        expect(commit_msg).to include('Fix applied by SmartRails')
      end
    end
    
    context 'when no changes to commit' do
      it 'returns success with message' do
        # Commit changes first
        git_manager.commit_changes(commit_message, files)
        
        # Try to commit again with no new changes
        result = git_manager.commit_changes('Another commit', files)
        
        expect(result[:success]).to be true
        expect(result[:message]).to include('nothing to commit')
      end
    end
  end
  
  describe '#create_stash' do
    before do
      # Create some changes to stash
      File.write(File.join(project_path, 'test_file.rb'), 'test content')
      File.write(File.join(project_path, 'app/models/user.rb'), 'class User; end')
    end
    
    it 'creates a stash with description' do
      description = 'Before applying SmartRails fixes'
      result = git_manager.create_stash(description)
      
      expect(result[:success]).to be true
      expect(result[:stash_id]).to be_a(String)
    end
    
    it 'cleans working tree after stashing' do
      git_manager.create_stash('test stash')
      expect(git_manager.clean_working_tree?).to be true
    end
    
    context 'when no changes to stash' do
      before do
        Dir.chdir(project_path) { system('git add . && git commit -m "clean up" --quiet') }
      end
      
      it 'returns failure' do
        result = git_manager.create_stash('empty stash')
        expect(result[:success]).to be false
      end
    end
  end
  
  describe '#apply_stash' do
    let(:stash_id) { 'stash@{0}' }
    
    before do
      # Create and stash some changes
      File.write(File.join(project_path, 'stashed_file.rb'), 'stashed content')
      git_manager.create_stash('test stash')
    end
    
    it 'applies specified stash' do
      result = git_manager.apply_stash(stash_id)
      
      expect(result[:success]).to be true
      expect(File.exist?(File.join(project_path, 'stashed_file.rb'))).to be true
    end
    
    context 'with invalid stash id' do
      it 'returns failure' do
        result = git_manager.apply_stash('stash@{999}')
        expect(result[:success]).to be false
      end
    end
  end
  
  describe '#rollback_commit' do
    let(:commit_sha) { nil }
    
    before do
      # Create a commit to rollback
      File.write(File.join(project_path, 'to_rollback.rb'), 'content to rollback')
      Dir.chdir(project_path) do
        system('git add to_rollback.rb')
        system('git commit -m "Commit to rollback" --quiet')
      end
    end
    
    it 'rolls back the specified commit' do
      # Get the commit SHA
      sha = Dir.chdir(project_path) { `git rev-parse HEAD`.strip }
      
      result = git_manager.rollback_commit(sha)
      
      expect(result[:success]).to be true
      expect(File.exist?(File.join(project_path, 'to_rollback.rb'))).to be false
    end
    
    context 'when rolling back latest commit' do
      it 'uses git reset' do
        # Mock git reset command
        allow(git_manager).to receive(:run_git_command).with('reset --hard HEAD~1').and_return({
          success: true,
          output: 'HEAD is now at abc1234'
        })
        
        result = git_manager.rollback_commit('latest')
        expect(result[:success]).to be true
      end
    end
  end
  
  describe '#cleanup_temp_branches' do
    let(:temp_branches) { ['smartrails-fix-1', 'smartrails-fix-2'] }
    let(:original_branch) { git_manager.current_branch }
    
    before do
      temp_branches.each { |branch| git_manager.create_temp_branch(branch) }
      git_manager.switch_to_branch(original_branch)
    end
    
    it 'deletes all temporary branches' do
      result = git_manager.cleanup_temp_branches
      
      expect(result[:success]).to be true
      expect(result[:cleaned_branches]).to match_array(temp_branches)
      
      # Verify branches are deleted
      Dir.chdir(project_path) do
        branches = `git branch`.split("\n").map(&:strip).reject { |b| b.start_with?('*') }
        temp_branches.each do |branch|
          expect(branches).not_to include(branch)
        end
      end
    end
    
    it 'clears temp branches tracking' do
      git_manager.cleanup_temp_branches
      temp_branches_list = git_manager.instance_variable_get(:@temp_branches)
      expect(temp_branches_list).to be_empty
    end
  end
  
  describe '#generate_patch' do
    before do
      # Create changes for patch
      File.write(File.join(project_path, 'app/models/user.rb'), <<~RUBY)
        class User < ApplicationRecord
          validates :email, presence: true
        end
      RUBY
      
      Dir.chdir(project_path) do
        system('git add .')
        system('git commit -m "Add user validations" --quiet')
      end
    end
    
    it 'generates patch for recent commits' do
      result = git_manager.generate_patch(1) # Last commit
      
      expect(result[:success]).to be true
      expect(result[:patch_content]).to include('validates :email')
      expect(result[:patch_file]).to end_with('.patch')
    end
    
    it 'saves patch to file' do
      result = git_manager.generate_patch(1)
      patch_file = File.join(project_path, result[:patch_file])
      
      expect(File.exist?(patch_file)).to be true
      
      patch_content = File.read(patch_file)
      expect(patch_content).to include('diff --git')
    end
  end
  
  describe '#apply_patch' do
    let(:patch_content) do
      <<~PATCH
        diff --git a/test_patch.rb b/test_patch.rb
        new file mode 100644
        index 0000000..d670460
        --- /dev/null
        +++ b/test_patch.rb
        @@ -0,0 +1 @@
        +puts "patched content"
      PATCH
    end
    
    before do
      @patch_file = File.join(project_path, 'test.patch')
      File.write(@patch_file, patch_content)
    end
    
    it 'applies patch from file' do
      result = git_manager.apply_patch(@patch_file)
      
      expect(result[:success]).to be true
      expect(File.exist?(File.join(project_path, 'test_patch.rb'))).to be true
    end
    
    context 'with invalid patch file' do
      it 'returns failure' do
        result = git_manager.apply_patch('nonexistent.patch')
        expect(result[:success]).to be false
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
        expect(result[:output]).to include('git: \'invalid-command\' is not a git command')
      end
    end
    
    describe '#generate_unique_branch_name' do
      before do
        # Create existing branch
        Dir.chdir(project_path) { system('git checkout -b existing-branch --quiet') }
        Dir.chdir(project_path) { system('git checkout main --quiet 2>/dev/null || git checkout master --quiet') }
      end
      
      it 'generates unique branch name when base exists' do
        unique_name = git_manager.send(:generate_unique_branch_name, 'existing-branch')
        
        expect(unique_name).to start_with('existing-branch')
        expect(unique_name).not_to eq('existing-branch')
        expect(unique_name).to match(/existing-branch-\d+/)
      end
      
      it 'returns base name when unique' do
        unique_name = git_manager.send(:generate_unique_branch_name, 'unique-branch-name')
        
        expect(unique_name).to eq('unique-branch-name')
      end
    end
  end
  
  describe 'integration with fix workflow' do
    it 'supports the complete fix workflow' do
      # 1. Create temp branch
      branch = git_manager.create_temp_branch('smartrails-fix-test')
      expect(git_manager.current_branch).to eq(branch)
      
      # 2. Make changes
      test_file = File.join(project_path, 'fixed_file.rb')
      File.write(test_file, 'fixed content')
      
      # 3. Commit changes
      commit_result = git_manager.commit_changes('Apply SmartRails fix', ['fixed_file.rb'])
      expect(commit_result[:success]).to be true
      
      # 4. Generate patch
      patch_result = git_manager.generate_patch(1)
      expect(patch_result[:success]).to be true
      
      # 5. Switch back to main branch
      original_branch = 'main'
      git_manager.switch_to_branch(original_branch) || git_manager.switch_to_branch('master')
      
      # 6. Cleanup temp branches
      cleanup_result = git_manager.cleanup_temp_branches
      expect(cleanup_result[:success]).to be true
    end
  end
end