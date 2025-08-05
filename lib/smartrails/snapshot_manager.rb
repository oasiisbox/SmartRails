# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'digest'

module SmartRails
  class SnapshotManager
    attr_reader :project_path, :snapshots_dir, :current_snapshot_id

    def initialize(project_path)
      @project_path = project_path
      @snapshots_dir = File.join(project_path, 'tmp', 'smartrails_snapshots')
      @current_snapshot_id = nil
      ensure_snapshots_directory
    end

    def create_snapshot(description = nil)
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      @current_snapshot_id = "snapshot_#{timestamp}_#{SecureRandom.hex(4)}"
      
      snapshot_path = File.join(@snapshots_dir, @current_snapshot_id)
      FileUtils.mkdir_p(snapshot_path)
      
      # Create snapshot metadata
      metadata = {
        id: @current_snapshot_id,
        description: description || "Automatic snapshot",
        timestamp: Time.now.iso8601,
        project_path: @project_path,
        git_commit: current_git_commit,
        file_checksums: calculate_file_checksums
      }
      
      # Save metadata
      File.write(
        File.join(snapshot_path, 'metadata.json'),
        JSON.pretty_generate(metadata)
      )
      
      # Create file backups for critical files
      backup_critical_files(snapshot_path)
      
      # Create git stash if possible
      create_git_stash if git_available?
      
      Rails.logger.info "Created snapshot: #{@current_snapshot_id}" if defined?(Rails)
      
      @current_snapshot_id
    end

    def restore_snapshot(snapshot_id)
      snapshot_path = File.join(@snapshots_dir, snapshot_id)
      
      unless File.exist?(snapshot_path)
        raise "Snapshot #{snapshot_id} not found"
      end
      
      metadata = load_snapshot_metadata(snapshot_id)
      
      begin
        # Restore from git stash if available
        if git_available? && metadata['git_stash_ref']
          restore_from_git_stash(metadata['git_stash_ref'])
        else
          # Restore from file backups
          restore_from_file_backups(snapshot_path)
        end
        
        # Verify restoration
        if verify_snapshot_restoration(metadata)
          Rails.logger.info "Successfully restored snapshot: #{snapshot_id}" if defined?(Rails)
          true
        else
          Rails.logger.error "Snapshot restoration verification failed" if defined?(Rails)
          false
        end
        
      rescue StandardError => e
        Rails.logger.error "Failed to restore snapshot #{snapshot_id}: #{e.message}" if defined?(Rails)
        false
      end
    end

    def list_snapshots
      return [] unless File.exist?(@snapshots_dir)
      
      Dir.glob(File.join(@snapshots_dir, 'snapshot_*')).map do |snapshot_path|
        snapshot_id = File.basename(snapshot_path)
        metadata = load_snapshot_metadata(snapshot_id)
        
        {
          id: snapshot_id,
          description: metadata['description'],
          timestamp: metadata['timestamp'],
          git_commit: metadata['git_commit'],
          file_count: metadata['file_checksums']&.size || 0
        }
      end.sort_by { |s| s[:timestamp] }.reverse
    end

    def cleanup_old_snapshots(keep_count = 10)
      snapshots = list_snapshots
      
      if snapshots.size > keep_count
        old_snapshots = snapshots[keep_count..-1]
        
        old_snapshots.each do |snapshot|
          delete_snapshot(snapshot[:id])
        end
        
        Rails.logger.info "Cleaned up #{old_snapshots.size} old snapshots" if defined?(Rails)
        old_snapshots.size
      else
        0
      end
    end

    def delete_snapshot(snapshot_id)
      snapshot_path = File.join(@snapshots_dir, snapshot_id)
      
      if File.exist?(snapshot_path)
        FileUtils.rm_rf(snapshot_path)
        Rails.logger.info "Deleted snapshot: #{snapshot_id}" if defined?(Rails)
        true
      else
        false
      end
    end

    def mark_snapshot_success(snapshot_id)
      snapshot_path = File.join(@snapshots_dir, snapshot_id)
      metadata_file = File.join(snapshot_path, 'metadata.json')
      
      return unless File.exist?(metadata_file)
      
      metadata = JSON.parse(File.read(metadata_file))
      metadata['status'] = 'success'
      metadata['completed_at'] = Time.now.iso8601
      
      File.write(metadata_file, JSON.pretty_generate(metadata))
    end

    def snapshot_size(snapshot_id)
      snapshot_path = File.join(@snapshots_dir, snapshot_id)
      return 0 unless File.exist?(snapshot_path)
      
      Dir.glob(File.join(snapshot_path, '**', '*')).sum do |file|
        File.file?(file) ? File.size(file) : 0
      end
    end

    private

    def ensure_snapshots_directory
      FileUtils.mkdir_p(@snapshots_dir)
      
      # Add .gitignore to exclude snapshots from git
      gitignore_file = File.join(@snapshots_dir, '.gitignore')
      unless File.exist?(gitignore_file)
        File.write(gitignore_file, "*\n!.gitignore\n")
      end
    end

    def backup_critical_files(snapshot_path)
      files_path = File.join(snapshot_path, 'files')
      FileUtils.mkdir_p(files_path)
      
      critical_files.each do |file_pattern|
        Dir.glob(File.join(@project_path, file_pattern)).each do |file|
          next unless File.file?(file)
          
          relative_path = file.sub("#{@project_path}/", '')
          backup_file_path = File.join(files_path, relative_path)
          
          # Create directory structure
          FileUtils.mkdir_p(File.dirname(backup_file_path))
          
          # Copy file
          FileUtils.cp(file, backup_file_path)
        end
      end
    end

    def restore_from_file_backups(snapshot_path)
      files_path = File.join(snapshot_path, 'files')
      return unless File.exist?(files_path)
      
      Dir.glob(File.join(files_path, '**', '*')).each do |backup_file|
        next unless File.file?(backup_file)
        
        relative_path = backup_file.sub("#{files_path}/", '')
        target_file = File.join(@project_path, relative_path)
        
        # Create directory structure
        FileUtils.mkdir_p(File.dirname(target_file))
        
        # Restore file
        FileUtils.cp(backup_file, target_file)
      end
    end

    def create_git_stash
      return unless git_available?
      
      # Check if there are changes to stash
      result = `cd #{@project_path} && git status --porcelain 2>/dev/null`
      return if result.strip.empty?
      
      # Create stash with SmartRails prefix
      stash_message = "SmartRails snapshot #{@current_snapshot_id}"
      `cd #{@project_path} && git stash push -m "#{stash_message}" 2>/dev/null`
      
      # Get stash reference
      stash_list = `cd #{@project_path} && git stash list --grep="#{stash_message}" 2>/dev/null`
      if match = stash_list.match(/^(stash@\{[^}]+\})/)
        return match[1]
      end
      
      nil
    end

    def restore_from_git_stash(stash_ref)
      return unless git_available?
      
      `cd #{@project_path} && git stash apply #{stash_ref} 2>/dev/null`
      $?.success?
    end

    def git_available?
      @git_available ||= begin
        `cd #{@project_path} && git status 2>/dev/null`
        $?.success?
      end
    end

    def current_git_commit
      return nil unless git_available?
      
      `cd #{@project_path} && git rev-parse HEAD 2>/dev/null`.strip
    end

    def calculate_file_checksums
      checksums = {}
      
      critical_files.each do |file_pattern|
        Dir.glob(File.join(@project_path, file_pattern)).each do |file|
          next unless File.file?(file)
          
          relative_path = file.sub("#{@project_path}/", '')
          checksums[relative_path] = Digest::MD5.file(file).hexdigest
        end
      end
      
      checksums
    end

    def verify_snapshot_restoration(metadata)
      return true unless metadata['file_checksums']
      
      metadata['file_checksums'].all? do |relative_path, expected_checksum|
        file_path = File.join(@project_path, relative_path)
        
        if File.exist?(file_path)
          actual_checksum = Digest::MD5.file(file_path).hexdigest
          actual_checksum == expected_checksum
        else
          false
        end
      end
    end

    def load_snapshot_metadata(snapshot_id)
      metadata_file = File.join(@snapshots_dir, snapshot_id, 'metadata.json')
      
      if File.exist?(metadata_file)
        JSON.parse(File.read(metadata_file))
      else
        {}
      end
    end

    # Files that are critical to backup/restore
    def critical_files
      [
        'Gemfile',
        'Gemfile.lock',
        'app/**/*.rb',
        'config/**/*.rb',
        'config/**/*.yml',
        'lib/**/*.rb',
        '.rubocop.yml',
        '.brakeman.ignore',
        'db/migrate/*.rb'
      ]
    end
  end
end