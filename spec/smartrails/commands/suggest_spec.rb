# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SmartRails::Commands::Suggest do
  let(:options) { { llm: 'ollama', model: 'test' } }
  let(:suggestion_response) { 'Great suggestion!' }
  let(:suggestor_double) do
    instance_double('Suggestor', name: 'TestSuggestor', suggest: suggestion_response)
  end

  describe '#execute' do
    it 'creates the reports directory before saving suggestions' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          expect(Dir.exist?('reports')).to be(false)

          command = described_class.new(options)

          allow(command).to receive(:get_content).and_return('content')
          allow(command).to receive(:create_suggestor).and_return(suggestor_double)
          allow(command).to receive(:say)

          command.execute

          expect(Dir.exist?('reports')).to be(true)
          expect(Dir.glob('reports/suggestion_*.txt')).not_to be_empty
        end
      end
    end
  end
end
