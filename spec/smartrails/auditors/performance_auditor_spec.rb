# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/auditors/performance_auditor'

RSpec.describe SmartRails::Auditors::PerformanceAuditor do
  let(:project_root) { create_temp_rails_project }
  let(:auditor) { described_class.new(project_root) }
  
  describe '#run' do
    it 'runs all performance checks' do
      expect(auditor).to receive(:check_caching_configuration)
      expect(auditor).to receive(:check_database_queries)
      expect(auditor).to receive(:check_asset_optimization)
      expect(auditor).to receive(:check_background_jobs)
      expect(auditor).to receive(:check_pagination)
      expect(auditor).to receive(:check_eager_loading)
      
      auditor.run
    end
  end
  
  describe '#check_caching_configuration' do
    let(:production_config_path) { project_root.join('config/environments/production.rb') }
    
    context 'when cache store is not configured' do
      before do
        create_config_file(project_root, 'environments/production.rb', <<~RUBY)
          Rails.application.configure do
            # No cache configuration
          end
        RUBY
      end
      
      it 'adds a medium severity issue for missing cache store' do
        issues = auditor.run
        cache_issue = issues.find { |i| i[:type] == 'Caching' && i[:message].include?('cache store') }
        
        expect(cache_issue).not_to be_nil
        expect(cache_issue[:severity]).to eq(:medium)
        expect(cache_issue[:file]).to include('production.rb')
      end
    end
    
    context 'when cache store is configured' do
      before do
        create_config_file(project_root, 'environments/production.rb', <<~RUBY)
          Rails.application.configure do
            config.cache_store = :redis_cache_store
          end
        RUBY
      end
      
      it 'does not add a cache store issue' do
        issues = auditor.run
        cache_issue = issues.find { |i| i[:type] == 'Caching' && i[:message].include?('cache store') }
        
        expect(cache_issue).to be_nil
      end
    end
    
    context 'when Redis is not in Gemfile' do
      before do
        create_config_file(project_root, 'environments/production.rb', <<~RUBY)
          Rails.application.configure do
            config.cache_store = :memory_store
          end
        RUBY
      end
      
      it 'adds a low severity issue for missing Redis' do
        issues = auditor.run
        redis_issue = issues.find { |i| i[:type] == 'Caching' && i[:message].include?('Redis') }
        
        expect(redis_issue).not_to be_nil
        expect(redis_issue[:severity]).to eq(:low)
        expect(redis_issue[:file]).to eq('Gemfile')
      end
    end
    
    context 'when Redis is in Gemfile' do
      before do
        File.write(project_root.join('Gemfile'), <<~RUBY)
          source 'https://rubygems.org'
          gem 'rails'
          gem 'redis'
        RUBY
        
        create_config_file(project_root, 'environments/production.rb', <<~RUBY)
          Rails.application.configure do
            config.cache_store = :redis_cache_store
          end
        RUBY
      end
      
      it 'does not add a Redis issue' do
        issues = auditor.run
        redis_issue = issues.find { |i| i[:type] == 'Caching' && i[:message].include?('Redis') }
        
        expect(redis_issue).to be_nil
      end
    end
  end
  
  describe '#check_database_queries' do
    context 'when rack-mini-profiler is not installed' do
      it 'adds a low severity issue' do
        issues = auditor.run
        profiler_issue = issues.find { |i| i[:type] == 'Performance Monitoring' }
        
        expect(profiler_issue).not_to be_nil
        expect(profiler_issue[:severity]).to eq(:low)
        expect(profiler_issue[:message]).to include('rack-mini-profiler')
      end
    end
    
    context 'when rack-mini-profiler is installed' do
      before do
        File.write(project_root.join('Gemfile'), <<~RUBY)
          source 'https://rubygems.org'
          gem 'rails'
          gem 'rack-mini-profiler'
        RUBY
      end
      
      it 'does not add a profiler issue' do
        issues = auditor.run
        profiler_issue = issues.find { |i| i[:type] == 'Performance Monitoring' }
        
        expect(profiler_issue).to be_nil
      end
    end
    
    context 'when database pool is not configured' do
      before do
        create_config_file(project_root, 'database.yml', <<~YAML)
          production:
            adapter: postgresql
            database: myapp_production
        YAML
      end
      
      it 'adds a medium severity issue' do
        issues = auditor.run
        pool_issue = issues.find { |i| i[:type] == 'Database Performance' }
        
        expect(pool_issue).not_to be_nil
        expect(pool_issue[:severity]).to eq(:medium)
        expect(pool_issue[:message]).to include('connection pool')
      end
    end
    
    context 'when database pool is configured' do
      before do
        create_config_file(project_root, 'database.yml', <<~YAML)
          production:
            adapter: postgresql
            database: myapp_production
            pool: 10
        YAML
      end
      
      it 'does not add a pool issue' do
        issues = auditor.run
        pool_issue = issues.find { |i| i[:type] == 'Database Performance' }
        
        expect(pool_issue).to be_nil
      end
    end
  end
  
  describe '#check_asset_optimization' do
    let(:production_config_path) { project_root.join('config/environments/production.rb') }
    
    context 'when asset compilation is enabled in production' do
      before do
        create_config_file(project_root, 'environments/production.rb', <<~RUBY)
          Rails.application.configure do
            config.assets.compile = true
          end
        RUBY
      end
      
      it 'adds a high severity issue' do
        issues = auditor.run
        asset_issue = issues.find { |i| i[:type] == 'Asset Performance' && i[:message].include?('compilation') }
        
        expect(asset_issue).not_to be_nil
        expect(asset_issue[:severity]).to eq(:high)
      end
    end
    
    context 'when asset compilation is disabled' do
      before do
        create_config_file(project_root, 'environments/production.rb', <<~RUBY)
          Rails.application.configure do
            config.assets.compile = false
          end
        RUBY
      end
      
      it 'does not add a compilation issue' do
        issues = auditor.run
        asset_issue = issues.find { |i| i[:type] == 'Asset Performance' && i[:message].include?('compilation') }
        
        expect(asset_issue).to be_nil
      end
    end
    
    context 'when CDN is not configured' do
      before do
        create_config_file(project_root, 'environments/production.rb', <<~RUBY)
          Rails.application.configure do
            config.assets.compile = false
          end
        RUBY
      end
      
      it 'adds a low severity issue for missing CDN' do
        issues = auditor.run
        cdn_issue = issues.find { |i| i[:type] == 'Asset Performance' && i[:message].include?('CDN') }
        
        expect(cdn_issue).not_to be_nil
        expect(cdn_issue[:severity]).to eq(:low)
      end
    end
    
    context 'when CDN is configured' do
      before do
        create_config_file(project_root, 'environments/production.rb', <<~RUBY)
          Rails.application.configure do
            config.assets.compile = false
            config.asset_host = 'https://cdn.example.com'
          end
        RUBY
      end
      
      it 'does not add a CDN issue' do
        issues = auditor.run
        cdn_issue = issues.find { |i| i[:type] == 'Asset Performance' && i[:message].include?('CDN') }
        
        expect(cdn_issue).to be_nil
      end
    end
  end
  
  describe '#check_background_jobs' do
    context 'when no background job processor is installed' do
      it 'adds a medium severity issue' do
        issues = auditor.run
        job_issue = issues.find { |i| i[:type] == 'Background Jobs' }
        
        expect(job_issue).not_to be_nil
        expect(job_issue[:severity]).to eq(:medium)
        expect(job_issue[:message]).to include('background job processor')
      end
    end
    
    context 'when Sidekiq is installed' do
      before do
        File.write(project_root.join('Gemfile'), <<~RUBY)
          source 'https://rubygems.org'
          gem 'rails'
          gem 'sidekiq'
        RUBY
      end
      
      it 'does not add a background job issue' do
        issues = auditor.run
        job_issue = issues.find { |i| i[:type] == 'Background Jobs' }
        
        expect(job_issue).to be_nil
      end
    end
    
    context 'when Good Job is installed' do
      before do
        File.write(project_root.join('Gemfile'), <<~RUBY)
          source 'https://rubygems.org'
          gem 'rails'
          gem 'good_job'
        RUBY
      end
      
      it 'does not add a background job issue' do
        issues = auditor.run
        job_issue = issues.find { |i| i[:type] == 'Background Jobs' }
        
        expect(job_issue).to be_nil
      end
    end
  end
  
  describe '#check_pagination' do
    context 'when no pagination gem is installed' do
      it 'adds a low severity issue' do
        issues = auditor.run
        pagination_issue = issues.find { |i| i[:type] == 'Performance' && i[:message].include?('pagination') }
        
        expect(pagination_issue).not_to be_nil
        expect(pagination_issue[:severity]).to eq(:low)
      end
    end
    
    context 'when Kaminari is installed' do
      before do
        File.write(project_root.join('Gemfile'), <<~RUBY)
          source 'https://rubygems.org'
          gem 'rails'
          gem 'kaminari'
        RUBY
      end
      
      it 'does not add a pagination issue' do
        issues = auditor.run
        pagination_issue = issues.find { |i| i[:type] == 'Performance' && i[:message].include?('pagination') }
        
        expect(pagination_issue).to be_nil
      end
    end
    
    context 'when Pagy is installed' do
      before do
        File.write(project_root.join('Gemfile'), <<~RUBY)
          source 'https://rubygems.org'
          gem 'rails'
          gem 'pagy'
        RUBY
      end
      
      it 'does not add a pagination issue' do
        issues = auditor.run
        pagination_issue = issues.find { |i| i[:type] == 'Performance' && i[:message].include?('pagination') }
        
        expect(pagination_issue).to be_nil
      end
    end
  end
  
  describe '#check_eager_loading' do
    context 'when potential N+1 queries are detected' do
      before do
        create_rails_controller(project_root, 'posts', <<~RUBY)
          class PostsController < ApplicationController
            def index
              @posts = Post.all
              @posts.each do |post|
                post.comments.each do |comment|
                  # Potential N+1 query
                end
              end
            end
          end
        RUBY
      end
      
      it 'adds a medium severity issue for N+1 queries' do
        issues = auditor.run
        n_plus_one_issue = issues.find { |i| i[:type] == 'N+1 Queries' }
        
        expect(n_plus_one_issue).not_to be_nil
        expect(n_plus_one_issue[:severity]).to eq(:medium)
        expect(n_plus_one_issue[:message]).to include('N+1 query')
      end
    end
    
    context 'when bootsnap is not installed' do
      it 'adds a low severity issue for bootsnap' do
        issues = auditor.run
        bootsnap_issue = issues.find { |i| i[:type] == 'Boot Performance' }
        
        expect(bootsnap_issue).not_to be_nil
        expect(bootsnap_issue[:severity]).to eq(:low)
        expect(bootsnap_issue[:message]).to include('Bootsnap')
      end
    end
    
    context 'when bootsnap is installed' do
      before do
        File.write(project_root.join('Gemfile'), <<~RUBY)
          source 'https://rubygems.org'
          gem 'rails'
          gem 'bootsnap'
        RUBY
      end
      
      it 'does not add a bootsnap issue' do
        issues = auditor.run
        bootsnap_issue = issues.find { |i| i[:type] == 'Boot Performance' }
        
        expect(bootsnap_issue).to be_nil
      end
    end
  end
  
  describe 'severity levels' do
    it 'assigns appropriate severity levels' do
      # Set up various performance issues
      create_config_file(project_root, 'environments/production.rb', <<~RUBY)
        Rails.application.configure do
          config.assets.compile = true  # High severity
        end
      RUBY
      
      create_config_file(project_root, 'database.yml', <<~YAML)
        production:
          adapter: postgresql
          # No pool configured - Medium severity
      YAML
      
      # Run auditor
      issues = auditor.run
      
      # Check high severity
      asset_issue = issues.find { |i| i[:type] == 'Asset Performance' && i[:message].include?('compilation') }
      expect(asset_issue[:severity]).to eq(:high)
      
      # Check medium severity
      pool_issue = issues.find { |i| i[:type] == 'Database Performance' }
      expect(pool_issue[:severity]).to eq(:medium)
      
      # Check low severity
      cdn_issue = issues.find { |i| i[:type] == 'Asset Performance' && i[:message].include?('CDN') }
      expect(cdn_issue[:severity]).to eq(:low)
    end
  end
end