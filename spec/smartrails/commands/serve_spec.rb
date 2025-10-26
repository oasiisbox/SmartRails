# frozen_string_literal: true

require 'rack/test'

RSpec.describe SmartRails::Commands::Serve do
  let(:options) { { host: '127.0.0.1', port: 4567 } }
  let(:project_root) { Pathname.new(create_temp_directory) }
  let(:reports_dir) { project_root.join('reports') }
  let(:command) { described_class.new(options) }

  before do
    FileUtils.mkdir_p(reports_dir)
    allow(command).to receive(:project_root).and_return(project_root)
  end

  describe '#create_app' do
    it 'configures the Sinatra app with provided options and reports path' do
      app = command.send(:create_app)

      expect(app.superclass).to eq(Sinatra::Base)
      expect(app.settings.port).to eq(4567)
      expect(app.settings.bind).to eq('127.0.0.1')
      expect(app.settings.reports_path).to eq(reports_dir)
    end
  end

  describe 'report listing' do
    include Rack::Test::Methods

    let(:app) { command.send(:create_app) }

    it 'returns JSON describing available reports' do
      report_path = reports_dir.join('audit_sample.json')
      File.write(report_path, { 'summary' => 'Test summary', 'issues' => [{ 'id' => 1 }] }.to_json)

      get '/api/reports'

      expect(last_response).to be_ok
      data = JSON.parse(last_response.body)

      expect(data).to contain_exactly(
        include(
          'filename' => 'audit_sample.json',
          'issues_count' => 1,
          'summary' => 'Test summary'
        )
      )
    end
  end
end
