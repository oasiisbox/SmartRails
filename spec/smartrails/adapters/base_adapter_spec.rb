# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/adapters/base_adapter'

RSpec.describe SmartRails::Adapters::BaseAdapter do
  let(:project_path) { create_temp_rails_project }
  let(:options) { { verbose: true } }
  let(:adapter) { described_class.new(project_path, options) }
  
  describe '#initialize' do
    it 'sets project path and options' do
      expect(adapter.project_path).to eq(project_path)
      expect(adapter.options).to eq(options)
    end
  end
  
  describe '#audit' do
    it 'raises NotImplementedError' do
      expect { adapter.audit }.to raise_error(NotImplementedError, /must implement #audit/)
    end
  end
  
  describe '#format_results' do
    it 'raises NotImplementedError' do
      expect { adapter.format_results([]) }.to raise_error(NotImplementedError, /must implement #format_results/)
    end
  end
  
  describe '#auto_fix' do
    it 'returns empty array by default' do
      expect(adapter.auto_fix([])).to eq([])
    end
  end
  
  describe '#severity_mapping' do
    it 'returns medium severity by default' do
      expect(adapter.severity_mapping('high')).to eq(:medium)
      expect(adapter.severity_mapping('critical')).to eq(:medium)
    end
  end
  
  describe '#run_command' do
    it 'executes command in project directory' do
      result = adapter.send(:run_command, 'echo "test"')
      
      expect(result).to have_key(:success)
      expect(result).to have_key(:output)
      expect(result).to have_key(:exit_code)
      expect(result[:success]).to be true
      expect(result[:output]).to include('test')
    end
    
    it 'handles command failures' do
      result = adapter.send(:run_command, 'nonexistent_command')
      
      expect(result[:success]).to be false
      expect(result[:exit_code]).not_to eq(0)
    end
  end
  
  describe '#file_exists?' do
    before do
      File.write(File.join(project_path, 'test_file.rb'), 'test content')
    end
    
    it 'returns true for existing files' do
      expect(adapter.send(:file_exists?, 'test_file.rb')).to be true
    end
    
    it 'returns false for non-existing files' do
      expect(adapter.send(:file_exists?, 'nonexistent.rb')).to be false
    end
  end
  
  describe '#read_file' do
    before do
      File.write(File.join(project_path, 'test_file.rb'), 'test content')
    end
    
    it 'reads file content' do
      content = adapter.send(:read_file, 'test_file.rb')
      expect(content).to eq('test content')
    end
  end
  
  describe '#write_file' do
    it 'writes content to file' do
      adapter.send(:write_file, 'new_file.rb', 'new content')
      
      file_path = File.join(project_path, 'new_file.rb')
      expect(File.exist?(file_path)).to be true
      expect(File.read(file_path)).to eq('new content')
    end
  end
  
  describe '#relative_path' do
    it 'converts absolute path to relative' do
      absolute_path = "#{project_path}/app/models/user.rb"
      relative = adapter.send(:relative_path, absolute_path)
      
      expect(relative).to eq('app/models/user.rb')
    end
  end
  
  describe '#create_issue' do
    let(:params) do
      {
        type: :security,
        severity: :high,
        category: :vulnerability,
        message: 'Test security issue',
        file: 'app/controllers/users_controller.rb',
        line: 10,
        column: 5,
        remediation: 'Fix the issue',
        auto_fixable: true,
        fix_command: 'run fix command',
        documentation_url: 'https://example.com/docs',
        metadata: { check: 'test_check' }
      }
    end
    
    it 'creates properly formatted issue' do
      issue = adapter.send(:create_issue, params)
      
      expect(issue).to include(
        tool: :base,
        type: :security,
        severity: :high,
        category: :vulnerability,
        message: 'Test security issue',
        file: 'app/controllers/users_controller.rb',
        line: 10,
        column: 5,
        remediation: 'Fix the issue',
        auto_fixable: true,
        fix_command: 'run fix command',
        documentation_url: 'https://example.com/docs',
        metadata: { check: 'test_check' }
      )
      expect(issue[:fingerprint]).to be_a(String)
      expect(issue[:fingerprint].length).to eq(16)
    end
    
    it 'uses defaults for missing params' do
      minimal_params = { message: 'Test message' }
      issue = adapter.send(:create_issue, minimal_params)
      
      expect(issue[:type]).to eq(:general)
      expect(issue[:severity]).to eq(:medium)
      expect(issue[:category]).to eq(:general)
      expect(issue[:auto_fixable]).to be false
      expect(issue[:metadata]).to eq({})
    end
  end
  
  describe '#tool_name' do
    it 'extracts tool name from class name' do
      expect(adapter.send(:tool_name)).to eq(:base)
    end
  end
  
  describe '#generate_fingerprint' do
    it 'generates consistent fingerprint' do
      params = {
        file: 'test.rb',
        line: 10,
        message: 'test message'
      }
      
      fingerprint1 = adapter.send(:generate_fingerprint, params)
      fingerprint2 = adapter.send(:generate_fingerprint, params)
      
      expect(fingerprint1).to eq(fingerprint2)
      expect(fingerprint1).to be_a(String)
      expect(fingerprint1.length).to eq(16)
    end
    
    it 'generates different fingerprints for different issues' do
      params1 = { file: 'test1.rb', line: 10, message: 'message1' }
      params2 = { file: 'test2.rb', line: 20, message: 'message2' }
      
      fingerprint1 = adapter.send(:generate_fingerprint, params1)
      fingerprint2 = adapter.send(:generate_fingerprint, params2)
      
      expect(fingerprint1).not_to eq(fingerprint2)
    end
  end
  
  describe '#gem_available?' do
    it 'returns true for available gems' do
      expect(adapter.send(:gem_available?, 'json')).to be true
    end
    
    it 'returns false for unavailable gems' do
      expect(adapter.send(:gem_available?, 'nonexistent_gem_12345')).to be false
    end
  end
  
  describe '#parse_json' do
    it 'parses valid JSON' do
      json = '{"key": "value", "number": 42}'
      result = adapter.send(:parse_json, json)
      
      expect(result).to eq({ 'key' => 'value', 'number' => 42 })
    end
    
    it 'returns empty hash for invalid JSON' do
      invalid_json = '{"invalid": json}'
      result = adapter.send(:parse_json, invalid_json)
      
      expect(result).to eq({})
    end
  end
  
  describe '#parse_yaml' do
    it 'parses valid YAML' do
      yaml = "key: value\nnumber: 42"
      result = adapter.send(:parse_yaml, yaml)
      
      expect(result).to eq({ 'key' => 'value', 'number' => 42 })
    end
    
    it 'returns empty hash for invalid YAML' do
      invalid_yaml = "key: value\n  invalid: yaml:"
      result = adapter.send(:parse_yaml, invalid_yaml)
      
      expect(result).to eq({})
    end
  end
end