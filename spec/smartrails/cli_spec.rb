# frozen_string_literal: true

RSpec.describe SmartRails::CLI do
  describe '.start' do
    it 'handles version command' do
      expect { described_class.start(['version']) }.to output(/#{SmartRails::VERSION}/o).to_stdout
    end

    it 'shows help when no command is provided' do
      expect { described_class.start([]) }.to output(/Commands:/).to_stdout
    end

    it 'shows help for unknown commands' do
      expect { described_class.start(['unknown_command']) }.to output(/Could not find command/).to_stderr
    end
  end

  describe 'audit command' do
    let(:project_root) { create_temp_rails_project }

    before do
      allow(Dir).to receive(:pwd).and_return(project_root)
    end

    it 'runs audit in current directory' do
      expect { described_class.start(['audit', '--auto']) }.not_to raise_error
    end
  end

  describe 'init command' do
    let(:temp_dir) { create_temp_directory }

    before do
      allow(Dir).to receive(:pwd).and_return(temp_dir)
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    it 'initializes a new project' do
      expect { described_class.start(%w[init test_project]) }.not_to raise_error

      config_file = File.join(temp_dir, '.smartrails.json')
      expect(File.exist?(config_file)).to be true

      config = JSON.parse(File.read(config_file))
      expect(config['name']).to eq('test_project')
    end
  end

  describe 'serve command' do
    it 'starts the web server' do
      # Mock the server to avoid actually starting it
      allow_any_instance_of(SmartRails::Commands::Serve).to receive(:start_server)

      expect { described_class.start(['serve', '--port', '9999']) }.not_to raise_error
    end
  end
end
