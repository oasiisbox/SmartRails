# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/auditors/performance_auditor'

RSpec.describe SmartRails::Auditors::PerformanceAuditor do
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

    it 'checks caching configuration' do
      expect(auditor).to receive(:check_caching_configuration)
      auditor.run
    end

    it 'checks database queries' do
      expect(auditor).to receive(:check_database_queries)
      auditor.run
    end

    it 'checks asset optimization' do
      expect(auditor).to receive(:check_asset_optimization)
      auditor.run
    end

    it 'checks background jobs' do
      expect(auditor).to receive(:check_background_jobs)
      auditor.run
    end

    it 'checks pagination' do
      expect(auditor).to receive(:check_pagination)
      auditor.run
    end

    it 'checks eager loading' do
      expect(auditor).to receive(:check_eager_loading)
      auditor.run
    end
  end

  describe '#check_caching_configuration' do
    context 'when cache store is not configured' do
      before do
        production_rb = File.join(project_root, 'config/environments/production.rb')
        content = <<~RUBY
          Rails.application.configure do
            config.active_record.dump_schema_after_migration = false
          end
        RUBY
        File.write(production_rb, content)
      end

      it 'reports missing cache store' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('No cache store configured') }).to be true
      end
    end

    context 'when Redis is not configured' do
      it 'suggests adding Redis' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('Redis gem not found') }).to be true
      end
    end
  end

  describe '#check_database_queries' do
    context 'when rack-mini-profiler is not configured' do
      it 'suggests adding rack-mini-profiler' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('rack-mini-profiler') }).to be true
      end
    end

    context 'when database pool is not configured' do
      before do
        database_yml = File.join(project_root, 'config/database.yml')
        content = <<~YAML
          default: &default
            adapter: sqlite3
            timeout: 5000

          development:
            <<: *default
            database: db/development.sqlite3
        YAML
        File.write(database_yml, content)
      end

      it 'reports missing connection pool' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('Database connection pool') }).to be true
      end
    end
  end

  describe '#check_asset_optimization' do
    context 'when asset compilation is enabled in production' do
      before do
        production_rb = File.join(project_root, 'config/environments/production.rb')
        content = <<~RUBY
          Rails.application.configure do
            config.assets.compile = true
          end
        RUBY
        File.write(production_rb, content)
      end

      it 'reports asset compilation issue' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('Asset compilation enabled') }).to be true
      end
    end

    context 'when CDN is not configured' do
      before do
        production_rb = File.join(project_root, 'config/environments/production.rb')
        content = <<~RUBY
          Rails.application.configure do
            config.assets.compile = false
          end
        RUBY
        File.write(production_rb, content)
      end

      it 'reports missing CDN configuration' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('No CDN configured') }).to be true
      end
    end
  end

  describe '#check_background_jobs' do
    context 'when no background job processor is configured' do
      it 'suggests adding a job processor' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('No background job processor') }).to be true
      end
    end
  end

  describe '#check_pagination' do
    context 'when no pagination gem is configured' do
      it 'suggests adding a pagination gem' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('No pagination gem') }).to be true
      end
    end
  end

  describe '#check_eager_loading' do
    context 'with potential N+1 queries' do
      before do
        create_controller(project_root, 'posts', <<~RUBY)
          class PostsController < ApplicationController
            def index
              @posts = Post.all
              @posts.each do |post|
                post.comments.count
              end
            end
          end
        RUBY
      end

      it 'detects potential N+1 queries' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('Potential N+1 query') }).to be true
      end
    end

    context 'when bootsnap is not configured' do
      it 'suggests adding Bootsnap' do
        auditor.run
        issues = auditor.issues
        expect(issues.any? { |i| i[:message].include?('Bootsnap gem not found') }).to be true
      end
    end
  end
end
