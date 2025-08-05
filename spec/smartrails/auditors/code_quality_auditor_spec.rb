# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/auditors/code_quality_auditor'

RSpec.describe SmartRails::Auditors::CodeQualityAuditor do
  let(:project_root) { create_temp_rails_project }
  let(:auditor) { described_class.new(project_root) }
  
  describe '#run' do
    it 'runs all code quality checks' do
      expect(auditor).to receive(:check_test_coverage)
      expect(auditor).to receive(:check_linting_configuration)
      expect(auditor).to receive(:check_code_documentation)
      expect(auditor).to receive(:check_dependency_updates)
      expect(auditor).to receive(:check_rails_best_practices)
      expect(auditor).to receive(:check_database_indexes)
      
      auditor.run
    end
  end
  
  describe '#check_test_coverage' do
    context 'when no test directory exists' do
      before do
        FileUtils.rm_rf(project_root.join('spec'))
        FileUtils.rm_rf(project_root.join('test'))
      end
      
      it 'adds a high severity issue' do
        issues = auditor.run
        test_issue = issues.find { |i| i[:type] == 'Testing' && i[:message].include?('No test directory') }
        
        expect(test_issue).not_to be_nil
        expect(test_issue[:severity]).to eq(:high)
      end
    end
    
    context 'when test directory exists but no test files' do
      before do
        FileUtils.mkdir_p(project_root.join('spec'))
      end
      
      it 'adds a high severity issue for missing tests' do
        issues = auditor.run
        test_issue = issues.find { |i| i[:type] == 'Testing' && i[:message].include?('No test files') }
        
        expect(test_issue).not_to be_nil
        expect(test_issue[:severity]).to eq(:high)
      end
    end
    
    context 'when test files exist' do
      before do
        FileUtils.mkdir_p(project_root.join('spec/models'))
        File.write(project_root.join('spec/models/user_spec.rb'), "# Test file")
      end
      
      it 'does not add a test files issue' do
        issues = auditor.run
        test_issue = issues.find { |i| i[:type] == 'Testing' }
        
        expect(test_issue).to be_nil
      end
      
      context 'when SimpleCov is not installed' do
        it 'adds a low severity issue for missing SimpleCov' do
          issues = auditor.run
          coverage_issue = issues.find { |i| i[:type] == 'Test Coverage' }
          
          expect(coverage_issue).not_to be_nil
          expect(coverage_issue[:severity]).to eq(:low)
          expect(coverage_issue[:message]).to include('SimpleCov')
        end
      end
      
      context 'when SimpleCov is installed' do
        before do
          File.write(project_root.join('Gemfile'), <<~RUBY)
            source 'https://rubygems.org'
            gem 'rails'
            gem 'simplecov', require: false, group: :test
          RUBY
        end
        
        it 'does not add a SimpleCov issue' do
          issues = auditor.run
          coverage_issue = issues.find { |i| i[:type] == 'Test Coverage' }
          
          expect(coverage_issue).to be_nil
        end
      end
    end
  end
  
  describe '#check_linting_configuration' do
    context 'when .rubocop.yml does not exist' do
      it 'adds a medium severity issue with auto-fix' do
        issues = auditor.run
        rubocop_issue = issues.find { |i| i[:type] == 'Code Style' && i[:message].include?('RuboCop configuration') }
        
        expect(rubocop_issue).not_to be_nil
        expect(rubocop_issue[:severity]).to eq(:medium)
        expect(rubocop_issue[:auto_fix]).to be_a(Proc)
      end
    end
    
    context 'when .rubocop.yml exists' do
      before do
        File.write(project_root.join('.rubocop.yml'), "AllCops:\n  NewCops: enable")
      end
      
      it 'does not add a configuration issue' do
        issues = auditor.run
        rubocop_issue = issues.find { |i| i[:type] == 'Code Style' && i[:message].include?('RuboCop configuration') }
        
        expect(rubocop_issue).to be_nil
      end
    end
    
    context 'when RuboCop is not in Gemfile' do
      before do
        File.write(project_root.join('.rubocop.yml'), "AllCops:\n  NewCops: enable")
      end
      
      it 'adds a medium severity issue for missing gem' do
        issues = auditor.run
        gem_issue = issues.find { |i| i[:type] == 'Code Style' && i[:message].include?('RuboCop gem not found') }
        
        expect(gem_issue).not_to be_nil
        expect(gem_issue[:severity]).to eq(:medium)
        expect(gem_issue[:file]).to eq('Gemfile')
      end
    end
    
    context 'when RuboCop is in Gemfile' do
      before do
        File.write(project_root.join('.rubocop.yml'), "AllCops:\n  NewCops: enable")
        File.write(project_root.join('Gemfile'), <<~RUBY)
          source 'https://rubygems.org'
          gem 'rails'
          gem 'rubocop', require: false
          gem 'rubocop-rails', require: false
        RUBY
      end
      
      it 'does not add a RuboCop gem issue' do
        issues = auditor.run
        gem_issue = issues.find { |i| i[:type] == 'Code Style' && i[:message].include?('RuboCop gem') }
        
        expect(gem_issue).to be_nil
      end
    end
  end
  
  describe '#check_code_documentation' do
    context 'when README is missing' do
      before do
        FileUtils.rm_f(project_root.join('README.md'))
        FileUtils.rm_f(project_root.join('README'))
      end
      
      it 'adds a medium severity issue' do
        issues = auditor.run
        doc_issue = issues.find { |i| i[:type] == 'Documentation' && i[:message].include?('README') }
        
        expect(doc_issue).not_to be_nil
        expect(doc_issue[:severity]).to eq(:medium)
      end
    end
    
    context 'when README exists' do
      before do
        File.write(project_root.join('README.md'), "# My Rails App")
      end
      
      it 'does not add a README issue' do
        issues = auditor.run
        doc_issue = issues.find { |i| i[:type] == 'Documentation' && i[:message].include?('README') }
        
        expect(doc_issue).to be_nil
      end
    end
    
    context 'when checking inline documentation' do
      before do
        File.write(project_root.join('README.md'), "# App")
        create_rails_controller(project_root, 'application', <<~RUBY)
          class ApplicationController < ActionController::Base
            def index
              render json: { status: 'ok' }
            end
            
            def show
              render json: { id: params[:id] }
            end
            
            def create
              Model.create(params)
            end
            
            def update
              Model.update(params)
            end
          end
        RUBY
      end
      
      it 'adds a low severity issue for insufficient documentation' do
        issues = auditor.run
        doc_issue = issues.find { |i| i[:type] == 'Documentation' && i[:message].include?('Insufficient inline') }
        
        expect(doc_issue).not_to be_nil
        expect(doc_issue[:severity]).to eq(:low)
      end
    end
  end
  
  describe '#check_dependency_updates' do
    context 'when Gemfile.lock is old' do
      before do
        FileUtils.touch(project_root.join('Gemfile.lock'), mtime: Time.now - (100 * 86400))
      end
      
      it 'adds a medium severity issue' do
        issues = auditor.run
        dep_issue = issues.find { |i| i[:type] == 'Dependencies' && i[:message].include?('90 days old') }
        
        expect(dep_issue).not_to be_nil
        expect(dep_issue[:severity]).to eq(:medium)
        expect(dep_issue[:file]).to eq('Gemfile.lock')
      end
    end
    
    context 'when Gemfile.lock is recent' do
      before do
        FileUtils.touch(project_root.join('Gemfile.lock'))
      end
      
      it 'does not add an outdated dependency issue' do
        issues = auditor.run
        dep_issue = issues.find { |i| i[:type] == 'Dependencies' && i[:message].include?('90 days old') }
        
        expect(dep_issue).to be_nil
      end
    end
    
    context 'when bundler-audit is not installed' do
      it 'adds a medium severity issue' do
        issues = auditor.run
        audit_issue = issues.find { |i| i[:type] == 'Dependencies' && i[:message].include?('bundler-audit') }
        
        expect(audit_issue).not_to be_nil
        expect(audit_issue[:severity]).to eq(:medium)
      end
    end
    
    context 'when bundler-audit is installed' do
      before do
        File.write(project_root.join('Gemfile'), <<~RUBY)
          source 'https://rubygems.org'
          gem 'rails'
          gem 'bundler-audit', require: false
        RUBY
      end
      
      it 'does not add a bundler-audit issue' do
        issues = auditor.run
        audit_issue = issues.find { |i| i[:type] == 'Dependencies' && i[:message].include?('bundler-audit') }
        
        expect(audit_issue).to be_nil
      end
    end
  end
  
  describe '#check_rails_best_practices' do
    context 'when Bullet gem is not installed' do
      it 'adds a low severity issue' do
        issues = auditor.run
        bullet_issue = issues.find { |i| i[:type] == 'Performance' && i[:message].include?('Bullet') }
        
        expect(bullet_issue).not_to be_nil
        expect(bullet_issue[:severity]).to eq(:low)
      end
    end
    
    context 'when Bullet gem is installed' do
      before do
        File.write(project_root.join('Gemfile'), <<~RUBY)
          source 'https://rubygems.org'
          gem 'rails'
          gem 'bullet', group: :development
        RUBY
      end
      
      it 'does not add a Bullet issue' do
        issues = auditor.run
        bullet_issue = issues.find { |i| i[:type] == 'Performance' && i[:message].include?('Bullet') }
        
        expect(bullet_issue).to be_nil
      end
    end
    
    context 'when checking migrations' do
      before do
        FileUtils.mkdir_p(project_root.join('db/migrate'))
        File.write(project_root.join('db/migrate/20240101_create_users.rb'), <<~RUBY)
          class CreateUsers < ActiveRecord::Migration[7.0]
            def change
              create_table :users do |t|
                t.string :name
                t.references :company
                t.timestamps
              end
            end
          end
        RUBY
      end
      
      it 'adds a medium severity issue for missing index on foreign key' do
        issues = auditor.run
        index_issue = issues.find { |i| i[:type] == 'Database' && i[:message].include?('Foreign key without index') }
        
        expect(index_issue).not_to be_nil
        expect(index_issue[:severity]).to eq(:medium)
      end
    end
  end
  
  describe '#check_database_indexes' do
    context 'when foreign keys lack indexes in schema' do
      before do
        File.write(project_root.join('db/schema.rb'), <<~RUBY)
          ActiveRecord::Schema.define(version: 2024_01_01) do
            create_table "posts" do |t|
              t.bigint "user_id"
              t.bigint "category_id"
              t.timestamps
            end
            
            add_index "posts", ["user_id"]
            # Missing index on category_id
          end
        RUBY
      end
      
      it 'adds a medium severity issue for missing index' do
        issues = auditor.run
        index_issue = issues.find { |i| i[:type] == 'Database Performance' && i[:message].include?('category_id') }
        
        expect(index_issue).not_to be_nil
        expect(index_issue[:severity]).to eq(:medium)
        expect(index_issue[:file]).to eq('db/schema.rb')
      end
    end
    
    context 'when all foreign keys have indexes' do
      before do
        File.write(project_root.join('db/schema.rb'), <<~RUBY)
          ActiveRecord::Schema.define(version: 2024_01_01) do
            create_table "posts" do |t|
              t.bigint "user_id"
              t.bigint "category_id"
              t.timestamps
            end
            
            add_index "posts", ["user_id"]
            add_index "posts", ["category_id"]
          end
        RUBY
      end
      
      it 'does not add index issues' do
        issues = auditor.run
        index_issues = issues.select { |i| i[:type] == 'Database Performance' }
        
        expect(index_issues).to be_empty
      end
    end
  end
  
  describe 'auto-fix functionality' do
    describe '#create_rubocop_config' do
      it 'creates a proper .rubocop.yml file' do
        issues = auditor.run
        rubocop_issue = issues.find { |i| i[:type] == 'Code Style' && i[:message].include?('RuboCop configuration') }
        
        expect(rubocop_issue[:auto_fix]).to be_a(Proc)
        rubocop_issue[:auto_fix].call
        
        config_path = project_root.join('.rubocop.yml')
        expect(config_path).to exist
        
        content = config_path.read
        expect(content).to include('rubocop-rails')
        expect(content).to include('rubocop-rspec')
        expect(content).to include('rubocop-performance')
        expect(content).to include('NewCops: enable')
      end
    end
  end
  
  describe 'severity levels' do
    it 'assigns appropriate severity levels' do
      # Remove test directory for high severity
      FileUtils.rm_rf(project_root.join('spec'))
      FileUtils.rm_rf(project_root.join('test'))
      
      # Old Gemfile.lock for medium severity
      FileUtils.touch(project_root.join('Gemfile.lock'), mtime: Time.now - (100 * 86400))
      
      issues = auditor.run
      
      # Check high severity
      test_issue = issues.find { |i| i[:type] == 'Testing' }
      expect(test_issue[:severity]).to eq(:high)
      
      # Check medium severity
      dep_issue = issues.find { |i| i[:type] == 'Dependencies' && i[:message].include?('90 days old') }
      expect(dep_issue[:severity]).to eq(:medium)
      
      # Check low severity
      bullet_issue = issues.find { |i| i[:type] == 'Performance' && i[:message].include?('Bullet') }
      expect(bullet_issue[:severity]).to eq(:low)
    end
  end
end