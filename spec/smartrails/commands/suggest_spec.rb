# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/commands/suggest'

RSpec.describe SmartRails::Commands::Suggest do
  include SpecHelpers::FileSystemHelper

  let(:temp_dir) { setup_temp_dir }
  let(:options) { { llm: 'ollama', model: 'llama3' } }
  let(:command) { described_class.new(options) }

  before do
    Dir.chdir(temp_dir)
    FileUtils.mkdir_p('reports')
  end

  after do
    cleanup_temp_dir
  end

  describe '#execute' do
    let(:mock_suggestor) { instance_double(SmartRails::Suggestors::OllamaSuggestor) }
    let(:response) { 'Here is my suggestion...' }

    before do
      allow(command).to receive(:create_suggestor).and_return(mock_suggestor)
      allow(mock_suggestor).to receive(:name).and_return('Ollama')
      allow(mock_suggestor).to receive(:suggest).and_return(response)
    end

    context 'with file option' do
      let(:test_file) { File.join(temp_dir, 'test.rb') }
      let(:options) { { llm: 'ollama', model: 'llama3', file: test_file } }

      before do
        File.write(test_file, 'class Test; end')
      end

      it 'reads content from file' do
        expect { command.execute }.to output(/Sending to/).to_stdout
        expect(mock_suggestor).to have_received(:suggest)
      end

      it 'displays the suggestion' do
        expect { command.execute }.to output(/Here is my suggestion/).to_stdout
      end

      it 'saves the suggestion' do
        command.execute
        suggestion_files = Dir.glob(File.join(temp_dir, 'reports/suggestion_*.txt'))
        expect(suggestion_files).not_to be_empty
      end
    end

    context 'with non-existent file' do
      let(:options) { { llm: 'ollama', model: 'llama3', file: 'nonexistent.rb' } }

      it 'shows error message' do
        expect { command.execute }.to output(/File not found/).to_stdout
      end

      it 'does not call suggestor' do
        command.execute
        expect(mock_suggestor).not_to have_received(:suggest)
      end
    end

    context 'with source argument' do
      it 'uses provided source' do
        command.execute('def test; end')
        expect(mock_suggestor).to have_received(:suggest).with('def test; end')
      end
    end

    context 'without source or file' do
      let(:report_file) { File.join(temp_dir, 'reports/audit_123.json') }

      before do
        File.write(report_file, { issues: [] }.to_json)
      end

      it 'uses latest audit report' do
        expect { command.execute }.to output(/Using latest audit report/).to_stdout
      end
    end

    context 'without any content source' do
      it 'shows error message' do
        expect { command.execute }.to output(/Please provide content/).to_stdout
      end
    end

    context 'when suggestor raises error' do
      before do
        allow(mock_suggestor).to receive(:suggest).and_raise(StandardError, 'Connection failed')
      end

      it 'displays error message' do
        expect { command.execute('test') }.to output(/Error: Connection failed/).to_stdout
      end

      it 'displays help message' do
        expect { command.execute('test') }.to output(/Make sure the LLM service is running/).to_stdout
      end
    end
  end

  describe '#check_connection' do
    let(:mock_suggestor) { instance_double(SmartRails::Suggestors::OllamaSuggestor) }

    before do
      allow(command).to receive(:create_suggestor).and_return(mock_suggestor)
      allow(mock_suggestor).to receive(:name).and_return('Ollama')
    end

    context 'when connection is successful' do
      before do
        allow(mock_suggestor).to receive(:check_connection).and_return(true)
      end

      it 'shows success message' do
        expect { command.check_connection }.to output(/Connection successful/).to_stdout
      end
    end

    context 'when connection fails' do
      before do
        allow(mock_suggestor).to receive(:check_connection).and_return(false)
      end

      it 'shows failure message' do
        expect { command.check_connection }.to output(/Connection failed/).to_stdout
      end
    end

    context 'when connection raises error' do
      before do
        allow(mock_suggestor).to receive(:check_connection).and_raise(StandardError, 'Network error')
      end

      it 'shows error message' do
        expect { command.check_connection }.to output(/Error: Network error/).to_stdout
      end
    end
  end

  describe '#create_suggestor' do
    context 'with openai option' do
      let(:options) { { llm: 'openai', model: 'gpt-4' } }

      it 'creates OpenAI suggestor' do
        suggestor = command.send(:create_suggestor)
        expect(suggestor).to be_a(SmartRails::Suggestors::OpenAISuggestor)
      end
    end

    context 'with ollama option' do
      let(:options) { { llm: 'ollama', model: 'llama3' } }

      it 'creates Ollama suggestor' do
        suggestor = command.send(:create_suggestor)
        expect(suggestor).to be_a(SmartRails::Suggestors::OllamaSuggestor)
      end
    end

    context 'with unknown option' do
      let(:options) { { llm: 'unknown', model: 'test' } }

      it 'defaults to Ollama suggestor' do
        suggestor = command.send(:create_suggestor)
        expect(suggestor).to be_a(SmartRails::Suggestors::OllamaSuggestor)
      end
    end
  end

  describe '#save_suggestion' do
    let(:response) { 'Test suggestion content' }

    it 'saves suggestion as text file' do
      command.send(:save_suggestion, response)
      text_files = Dir.glob(File.join(temp_dir, 'reports/suggestion_*.txt'))
      expect(text_files).not_to be_empty
      expect(File.read(text_files.first)).to eq(response)
    end

    it 'saves suggestion as markdown file' do
      command.send(:save_suggestion, response)
      md_files = Dir.glob(File.join(temp_dir, 'reports/suggestion_*.md'))
      expect(md_files).not_to be_empty

      content = File.read(md_files.first)
      expect(content).to include('# AI Suggestion Report')
      expect(content).to include(response)
    end
  end
end
