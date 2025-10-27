# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/auditors/code_quality_auditor'

RSpec.describe SmartRails::Auditors::CodeQualityAuditor do
  include SpecHelpers::RailsProjectHelper
  include SpecHelpers::AuditorHelper

  let(:temp_dir) { setup_temp_dir }
  let(:project_root) { create_rails_project('test_app') }
  let(:auditor) { described_class.new(project_root) }

  after do
    cleanup_temp_dir
  end

  describe '#run' do
    it 'returns an array of issues' do
      result = auditor.run
      expect(result).to be_an(Array)
    end

    it 'checks test coverage' do
      expect(auditor).to receive(:check_test_coverage)
      auditor.run
    end

    it 'checks linting configuration' do
      expect(auditor).to receive(:check_linting_configuration)
      auditor.run
    end

    it 'checks code documentation' do
      expect(auditor).to receive(:check_code_documentation)
      auditor.run
    end

    it 'checks dependency updates' do
      expect(auditor).to receive(:check_dependency_updates)
      auditor.run
    end

    it 'checks Rails best practices' do
      expect(auditor).to receive(:check_rails_best_practices)
      auditor.run
    end

    it 'checks database indexes' do
      expect(auditor).to receive(:check_database_indexes)
      auditor.run
    end
  end

  describe '#check_test_coverage' do
    context 'when no test directory exists' do
      before do
        FileUtils.rm_rf(File.join(project_root, 'spec'))
        FileUtils.rm_rf(File.join(project_root, 'test'))
      end

      it 'reports missing test directory' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('No test directory') }).to be true
      end
    end

    context 'when test directory exists but no test files' do
      it 'reports missing test files' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('No test files') }).to be true
      end
    end

    context 'when SimpleCov is not configured' do
      it 'suggests adding SimpleCov' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('SimpleCov') }).to be true
      end
    end
  end

  describe '#check_linting_configuration' do
    context 'when .rubocop.yml does not exist' do
      before do
        FileUtils.rm_f(File.join(project_root, '.rubocop.yml'))
      end

      it 'reports missing RuboCop configuration' do
        auditor.run
        issues = auditor.issues
        rubocop_issue = issues.find { |i| i[:message].include?('RuboCop configuration') }
        expect(rubocop_issue).not_to be_nil
        expect(rubocop_issue[:auto_fix]).not_to be_nil
      end

      it 'provides auto-fix for creating RuboCop config' do
        auditor.run
        rubocop_issue = auditor.issues.find { |i| i[:message].include?('RuboCop configuration') }

        rubocop_issue[:auto_fix].call
        expect(File.exist?(File.join(project_root, '.rubocop.yml'))).to be true
      end
    end

    context 'when RuboCop is not in Gemfile' do
      it 'reports missing RuboCop gem' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('RuboCop gem not found') }).to be true
      end
    end
  end

  describe '#check_code_documentation' do
    context 'when README is missing' do
      before do
        FileUtils.rm_f(File.join(project_root, 'README.md'))
      end

      it 'reports missing README' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('No README') }).to be true
      end
    end

    context 'when code has insufficient documentation' do
      before do
        controller_file = File.join(project_root, 'app/controllers/application_controller.rb')
        content = <<~RUBY
          class ApplicationController < ActionController::Base
            def index
              render json: { message: 'Hello' }
            end
            def show
              render json: { id: params[:id] }
            end
            def create
              render json: { status: 'created' }
            end
          end
        RUBY
        File.write(controller_file, content)
      end

      it 'reports insufficient documentation' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('Insufficient inline documentation') }).to be true
      end
    end
  end

  describe '#check_dependency_updates' do
    context 'when Gemfile.lock is old' do
      before do
        lockfile = File.join(project_root, 'Gemfile.lock')
        File.write(lockfile, 'GEM')
        # Set mtime to 100 days ago
        File.utime(Time.now, Time.now - (100 * 86400), lockfile)
      end

      it 'reports outdated dependencies' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('Gemfile.lock is over 90 days old') }).to be true
      end
    end

    context 'when bundler-audit is not configured' do
      it 'suggests adding bundler-audit' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('bundler-audit') }).to be true
      end
    end
  end

  describe '#check_rails_best_practices' do
    context 'when Bullet gem is not configured' do
      it 'suggests adding Bullet' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('Bullet gem') }).to be true
      end
    end

    context 'with migrations missing indexes' do
      before do
        migration_dir = File.join(project_root, 'db/migrate')
        FileUtils.mkdir_p(migration_dir)

        migration_file = File.join(migration_dir, '20240101000000_create_users.rb')
        content = <<~RUBY
          class CreateUsers < ActiveRecord::Migration[7.0]
            def change
              create_table :users do |t|
                t.string :name
                t.references :organization
                t.timestamps
              end
            end
          end
        RUBY
        File.write(migration_file, content)
      end

      it 'reports missing index on foreign key' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('Foreign key without index') }).to be true
      end
    end
  end

  describe '#check_database_indexes' do
    context 'with schema having foreign keys without indexes' do
      before do
        schema_file = File.join(project_root, 'db/schema.rb')
        schema_content = <<~RUBY
          ActiveRecord::Schema.define(version: 2024_01_01_000000) do
            create_table "posts", force: :cascade do |t|
              t.string "title"
              t.integer "user_id"
              t.bigint "category_id"
              t.timestamps
            end
          end
        RUBY
        File.write(schema_file, schema_content)
      end

      it 'reports missing indexes' do
        auditor.run
        issues = auditor.issues
        missing_index_issues = issues.select { |i| i[:message].include?('Missing index on foreign key') }
        expect(missing_index_issues.count).to be >= 1
      end
    end
  end

  describe '#create_rubocop_config' do
    it 'creates valid RuboCop configuration' do
      auditor.send(:create_rubocop_config)

      config_file = File.join(project_root, '.rubocop.yml')
      expect(File.exist?(config_file)).to be true

      content = File.read(config_file)
      expect(content).to include('require:')
      expect(content).to include('rubocop-rails')
      expect(content).to include('AllCops:')
    end
  end
end
