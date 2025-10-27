# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/suggestors/base_suggestor'

RSpec.describe SmartRails::Suggestors::BaseSuggestor do
  # Create a test subclass to test the base functionality
  let(:test_suggestor_class) do
    Class.new(described_class) do
      def suggest(content)
        "Suggestion for: #{content}"
      end

      def check_connection
        true
      end

      protected

      def default_model
        'test-model'
      end
    end
  end

  let(:suggestor) { test_suggestor_class.new }

  describe '#initialize' do
    context 'without model parameter' do
      it 'uses default model' do
        expect(suggestor.model).to eq('test-model')
      end
    end

    context 'with model parameter' do
      let(:custom_suggestor) { test_suggestor_class.new(model: 'custom-model') }

      it 'uses provided model' do
        expect(custom_suggestor.model).to eq('custom-model')
      end
    end
  end

  describe '#name' do
    it 'returns the class name without Suggestor suffix' do
      # The test class is anonymous, so we need to stub the name
      allow(test_suggestor_class).to receive(:name).and_return('SmartRails::Suggestors::TestSuggestor')
      expect(suggestor.name).to eq('Test')
    end

    it 'handles different suggestor class names' do
      ollama_class = Class.new(described_class) do
        def self.name
          'SmartRails::Suggestors::OllamaSuggestor'
        end
      end
      expect(ollama_class.new(model: 'test').name).to eq('Ollama')
    end
  end

  describe '#suggest' do
    context 'in base class' do
      let(:base_suggestor) { described_class.new(model: 'test') }

      it 'raises NotImplementedError' do
        expect { base_suggestor.suggest('test') }.to raise_error(NotImplementedError, /suggest method/)
      end
    end

    context 'in subclass' do
      it 'can be implemented' do
        expect(suggestor.suggest('test content')).to eq('Suggestion for: test content')
      end
    end
  end

  describe '#check_connection' do
    context 'in base class' do
      let(:base_suggestor) { described_class.new(model: 'test') }

      it 'raises NotImplementedError' do
        expect { base_suggestor.check_connection }.to raise_error(NotImplementedError, /check_connection method/)
      end
    end

    context 'in subclass' do
      it 'can be implemented' do
        expect(suggestor.check_connection).to be true
      end
    end
  end

  describe '#default_model' do
    context 'in base class' do
      let(:base_suggestor_class) { described_class }

      it 'raises NotImplementedError when called' do
        expect do
          base_suggestor_class.new(model: nil)
        end.to raise_error(NotImplementedError, /default_model method/)
      end
    end

    context 'in subclass' do
      it 'can be implemented' do
        expect(suggestor.send(:default_model)).to eq('test-model')
      end
    end
  end

  describe '#build_prompt' do
    let(:content) { 'def test; end' }

    it 'includes the content' do
      prompt = suggestor.send(:build_prompt, content)
      expect(prompt).to include(content)
    end

    it 'includes security analysis request' do
      prompt = suggestor.send(:build_prompt, content)
      expect(prompt).to include('Security vulnerabilities')
    end

    it 'includes performance analysis request' do
      prompt = suggestor.send(:build_prompt, content)
      expect(prompt).to include('Performance optimization')
    end

    it 'includes code quality analysis request' do
      prompt = suggestor.send(:build_prompt, content)
      expect(prompt).to include('Code quality improvements')
    end

    it 'includes Rails best practices request' do
      prompt = suggestor.send(:build_prompt, content)
      expect(prompt).to include('Rails best practices')
    end

    it 'includes bug detection request' do
      prompt = suggestor.send(:build_prompt, content)
      expect(prompt).to include('Potential bugs')
    end

    it 'requests specific recommendations' do
      prompt = suggestor.send(:build_prompt, content)
      expect(prompt).to include('actionable recommendations')
    end

    it 'requests code examples' do
      prompt = suggestor.send(:build_prompt, content)
      expect(prompt).to include('code examples')
    end
  end

  describe 'subclass implementation pattern' do
    it 'allows creating custom suggestors' do
      custom_suggestor = Class.new(described_class) do
        def suggest(content)
          "Custom: #{content}"
        end

        def check_connection
          false
        end

        protected

        def default_model
          'custom'
        end
      end

      instance = custom_suggestor.new
      expect(instance.suggest('test')).to eq('Custom: test')
      expect(instance.check_connection).to be false
      expect(instance.model).to eq('custom')
    end
  end
end
