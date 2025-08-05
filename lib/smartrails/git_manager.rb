# frozen_string_literal: true

module SmartRails
  class GitManager
    attr_reader :project_path

    def initialize(project_path)
      @project_path = project_path
    end

    def create_fix_branch(branch_name)
      return false unless git_available?
      
      # Ensure we're on a clean state
      return false unless working_directory_clean?
      
      # Create and checkout new branch
      result = run_git_command("checkout -b #{branch_name}")
      
      if result[:success]
        Rails.logger.info "Created fix branch: #{branch_name}" if defined?(Rails)
        true
      else
        Rails.logger.error "Failed to create branch #{branch_name}: #{result[:output]}" if defined?(Rails)
        false
      end
    end

    def commit_fixes(fixes, commit_message)
      return false unless git_available?
      return false if fixes.empty?
      
      # Stage all modified files
      modified_files = fixes.flat_map { |fix| fix[:files_modified] || [] }.uniq.compact
      
      modified_files.each do |file|
        result = run_git_command("add #{file}")
        unless result[:success]
          Rails.logger.error "Failed to stage file #{file}: #{result[:output]}" if defined?(Rails)
          return false
        end
      end
      
      # Create commit with detailed message
      full_message = build_commit_message(commit_message, fixes)
      
      result = run_git_command("commit -m \"#{escape_commit_message(full_message)}\"")
      
      if result[:success]
        Rails.logger.info "Committed fixes: #{fixes.size} fixes applied" if defined?(Rails)
        true
      else
        Rails.logger.error "Failed to commit fixes: #{result[:output]}" if defined?(Rails)
        false
      end
    end

    def create_patch(fixes, output_path = nil)
      return nil unless git_available?
      
      # Generate patch from last commit
      result = run_git_command("format-patch -1 HEAD --stdout")
      
      return nil unless result[:success]
      
      patch_content = result[:output]
      
      # Save patch to file if path provided
      if output_path
        File.write(output_path, patch_content)
        Rails.logger.info "Patch saved to: #{output_path}" if defined?(Rails)
      end
      
      {
        content: patch_content,
        file_path: output_path,
        fixes_count: fixes.size,
        commit_hash: current_commit_hash
      }
    end

    def create_pull_request_branch(base_branch = 'main')
      return false unless git_available?
      
      # Ensure we're not on the base branch
      current_branch = current_branch_name
      return false if current_branch == base_branch
      
      # Push current branch to origin
      result = run_git_command("push -u origin #{current_branch}")
      
      if result[:success]
        Rails.logger.info "Pushed branch #{current_branch} to origin" if defined?(Rails)
        
        # Return information for PR creation
        {
          branch_name: current_branch,
          base_branch: base_branch,
          remote_url: get_remote_url,
          commit_count: count_commits_ahead(base_branch)
        }
      else
        Rails.logger.error "Failed to push branch: #{result[:output]}" if defined?(Rails)
        false
      end
    end

    def working_directory_clean?
      return false unless git_available?
      
      result = run_git_command("status --porcelain")
      result[:success] && result[:output].strip.empty?
    end

    def current_branch_name
      return nil unless git_available?
      
      result = run_git_command("rev-parse --abbrev-ref HEAD")
      result[:success] ? result[:output].strip : nil
    end

    def current_commit_hash
      return nil unless git_available?
      
      result = run_git_command("rev-parse HEAD")
      result[:success] ? result[:output].strip : nil
    end

    def get_remote_url
      return nil unless git_available?
      
      result = run_git_command("config --get remote.origin.url")
      result[:success] ? result[:output].strip : nil
    end

    def count_commits_ahead(base_branch)
      return 0 unless git_available?
      
      result = run_git_command("rev-list --count #{base_branch}..HEAD")
      result[:success] ? result[:output].strip.to_i : 0
    end

    def revert_last_commit
      return false unless git_available?
      
      result = run_git_command("revert --no-edit HEAD")
      
      if result[:success]
        Rails.logger.info "Reverted last commit" if defined?(Rails)
        true
      else
        Rails.logger.error "Failed to revert commit: #{result[:output]}" if defined?(Rails)
        false
      end
    end

    def switch_to_branch(branch_name)
      return false unless git_available?
      
      result = run_git_command("checkout #{branch_name}")
      
      if result[:success]
        Rails.logger.info "Switched to branch: #{branch_name}" if defined?(Rails)
        true
      else
        Rails.logger.error "Failed to switch to branch #{branch_name}: #{result[:output]}" if defined?(Rails)
        false
      end
    end

    def delete_branch(branch_name)
      return false unless git_available?
      return false if current_branch_name == branch_name
      
      result = run_git_command("branch -D #{branch_name}")
      
      if result[:success]
        Rails.logger.info "Deleted branch: #{branch_name}" if defined?(Rails)
        
        # Also try to delete remote branch
        run_git_command("push origin --delete #{branch_name}")
        
        true
      else
        Rails.logger.error "Failed to delete branch #{branch_name}: #{result[:output]}" if defined?(Rails)
        false
      end
    end

    def get_file_history(file_path, limit = 10)
      return [] unless git_available?
      
      result = run_git_command("log --oneline -#{limit} -- #{file_path}")
      
      if result[:success]
        result[:output].split("\n").map do |line|
          parts = line.split(' ', 2)
          {
            commit_hash: parts[0],
            message: parts[1] || '',
            file: file_path
          }
        end
      else
        []
      end
    end

    def generate_changelog(since_commit = nil)
      return '' unless git_available?
      
      command = if since_commit
                  "log #{since_commit}..HEAD --oneline --grep='SmartRails'"
                else
                  "log --oneline --grep='SmartRails' -10"
                end
      
      result = run_git_command(command)
      
      if result[:success]
        changelog = "# SmartRails Fixes Changelog\n\n"
        
        result[:output].split("\n").each do |line|
          parts = line.split(' ', 2)
          changelog += "- #{parts[1]} (#{parts[0]})\n" if parts.size > 1
        end
        
        changelog
      else
        ''
      end
    end

    def git_available?
      @git_available ||= begin
        result = run_git_command("status")
        result[:success]
      end
    end

    private

    def run_git_command(command)
      full_command = "cd #{@project_path} && git #{command}"
      output = `#{full_command} 2>&1`
      
      {
        success: $?.success?,
        output: output,
        command: command,
        exit_code: $?.exitstatus
      }
    end

    def build_commit_message(base_message, fixes)
      message_parts = [base_message]
      message_parts << ""
      
      # Add summary
      message_parts << "Applied #{fixes.size} automatic fixes:"
      
      # Group fixes by tool
      fixes_by_tool = fixes.group_by { |fix| fix[:tool] || 'unknown' }
      
      fixes_by_tool.each do |tool, tool_fixes|
        message_parts << "- #{tool}: #{tool_fixes.size} fixes"
      end
      
      message_parts << ""
      
      # Add details for each fix
      fixes.each_with_index do |fix, index|
        if fix[:description]
          message_parts << "#{index + 1}. #{fix[:description]}"
        end
      end
      
      message_parts << ""
      message_parts << "🤖 Generated with SmartRails"
      message_parts << "Co-Authored-By: SmartRails <noreply@oasiisbox.com>"
      
      message_parts.join("\n")
    end

    def escape_commit_message(message)
      message.gsub('"', '\\"').gsub('`', '\\`').gsub('$', '\\$')
    end
  end
end