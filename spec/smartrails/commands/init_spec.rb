# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/commands/init'

RSpec.describe SmartRails::Commands::Init do
  include SpecHelpers::FileSystemHelper

  let(:temp_dir) { setup_temp_dir }
  let(:project_name) { 'test_project' }
  let(:command) { described_class.new }

  before do
    Dir.chdir(temp_dir)
  end

  after do
    cleanup_temp_dir
  end

  describe '#execute' do
    it 'creates project directory' do
      command.execute(project_name)

      project_path = File.join(temp_dir, project_name)
      expect(File.directory?(project_path)).to be true
    end

    it 'creates configuration file' do
      command.execute(project_name)

      config_file = File.join(temp_dir, project_name, '.smartrails.json')
      expect(File.exist?(config_file)).to be true
    end

    it 'saves correct configuration' do
      command.execute(project_name)

      config_file = File.join(temp_dir, project_name, '.smartrails.json')
      config = JSON.parse(File.read(config_file))

      expect(config['name']).to eq(project_name)
      expect(config['version']).to eq(SmartRails::VERSION)
      expect(config['ruby_version']).to eq(RUBY_VERSION)
      expect(config).to have_key('created_at')
    end

    it 'creates necessary directories' do
      command.execute(project_name)

      project_path = File.join(temp_dir, project_name)
      expect(File.directory?(File.join(project_path, 'reports'))).to be true
      expect(File.directory?(File.join(project_path, 'logs'))).to be true
      expect(File.directory?(File.join(project_path, 'agents'))).to be true
    end

    context 'with Rails project' do
      before do
        project_path = File.join(temp_dir, project_name)
        FileUtils.mkdir_p(project_path)

        Dir.chdir(project_path) do
          File.write('Gemfile', <<~GEMFILE)
            source 'https://rubygems.org'
            gem 'rails', '7.0.4'
          GEMFILE
        end

        Dir.chdir(temp_dir)
      end

      it 'detects Rails version from Gemfile' do
        command.execute(project_name)

        config_file = File.join(temp_dir, project_name, '.smartrails.json')
        config = JSON.parse(File.read(config_file))

        expect(config['rails_version']).to eq('7.0.4')
      end
    end

    context 'without Rails project' do
      it 'sets rails_version to nil' do
        command.execute(project_name)

        config_file = File.join(temp_dir, project_name, '.smartrails.json')
        config = JSON.parse(File.read(config_file))

        expect(config['rails_version']).to be_nil
      end
    end

    it 'displays success messages' do
      expect { command.execute(project_name) }.to output(/Initializing SmartRails/).to_stdout
    end
  end

  describe '#detect_rails_version' do
    it 'returns nil when no Gemfile exists' do
      version = command.send(:detect_rails_version)
      expect(version).to be_nil
    end

    it 'returns nil when Gemfile has no Rails gem' do
      File.write(File.join(temp_dir, 'Gemfile'), <<~GEMFILE)
        source 'https://rubygems.org'
        gem 'rspec'
      GEMFILE

      version = command.send(:detect_rails_version)
      expect(version).to be_nil
    end

    it 'parses Rails version with double quotes' do
      File.write(File.join(temp_dir, 'Gemfile'), <<~GEMFILE)
        source 'https://rubygems.org'
        gem "rails", "6.1.0"
      GEMFILE

      version = command.send(:detect_rails_version)
      expect(version).to eq('6.1.0')
    end

    it 'parses Rails version with single quotes' do
      File.write(File.join(temp_dir, 'Gemfile'), <<~GEMFILE)
        source 'https://rubygems.org'
        gem 'rails', '7.0.4'
      GEMFILE

      version = command.send(:detect_rails_version)
      expect(version).to eq('7.0.4')
    end
  end
end
