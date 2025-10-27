# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'smartrails/commands/serve'

RSpec.describe SmartRails::Commands::Serve do
  include Rack::Test::Methods
  include SpecHelpers::RailsProjectHelper

  let(:temp_dir) { setup_temp_dir }
  let(:project_root) { Pathname.new(temp_dir) }
  let(:reports_dir) { project_root.join('reports') }
  let(:options) { { host: 'localhost', port: 4567 } }
  let(:command) { described_class.new(options) }

  before do
    allow(command).to receive(:project_root).and_return(project_root)
    FileUtils.mkdir_p(reports_dir)

    # Create sample report files
    File.write(reports_dir.join('audit_123.json'), { issues: [] }.to_json)
    File.write(reports_dir.join('audit_456.json'), { issues: [{ type: 'test' }] }.to_json)
    File.write(reports_dir.join('audit_123.html'), '<html>Report</html>')
  end

  after do
    cleanup_temp_dir
  end

  describe '#execute' do
    it 'creates necessary directories' do
      expect(command).to receive(:ensure_directories)
      expect(command).to receive(:say).at_least(:once)

      app = command.send(:create_app)
      expect(app).to be_a(Class)
    end
  end

  describe 'web interface' do
    def app
      command.send(:create_app)
    end

    describe 'GET /' do
      it 'lists all reports' do
        get '/'
        expect(last_response).to be_ok
      end
    end

    describe 'GET /report/:filename' do
      context 'with valid filename' do
        it 'serves JSON report' do
          get '/report/audit_123.json'
          expect(last_response).to be_ok
          expect(last_response.content_type).to include('application/json')
        end

        it 'serves HTML report' do
          get '/report/audit_123.html'
          expect(last_response).to be_ok
          expect(last_response.content_type).to include('text/html')
        end
      end

      context 'with non-existent file' do
        it 'returns 404' do
          get '/report/nonexistent.json'
          expect(last_response.status).to eq(404)
        end
      end

      context 'with path traversal attempts' do
        it 'blocks attempts with ..' do
          get '/report/../../../etc/passwd'
          expect(last_response.status).to eq(403)
          expect(last_response.body).to include('Access denied')
        end

        it 'blocks attempts with multiple ..' do
          get '/report/../../sensitive.txt'
          expect(last_response.status).to eq(403)
          expect(last_response.body).to include('Access denied')
        end

        it 'blocks attempts with encoded ..' do
          get '/report/..%2F..%2Fetc%2Fpasswd'
          expect(last_response.status).to eq(403)
        end

        it 'blocks attempts with absolute paths' do
          get '/report//etc/passwd'
          expect(last_response.status).to eq(403)
        end

        it 'blocks attempts with directory traversal' do
          get '/report/subdir/../../../etc/passwd'
          expect(last_response.status).to eq(403)
        end
      end

      context 'with valid filenames containing special characters' do
        before do
          File.write(reports_dir.join('audit_test-report_2024.json'), { test: true }.to_json)
        end

        it 'allows dashes and underscores' do
          get '/report/audit_test-report_2024.json'
          expect(last_response).to be_ok
        end
      end
    end

    describe 'GET /api/reports' do
      it 'returns JSON list of reports' do
        get '/api/reports'
        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/json')

        data = JSON.parse(last_response.body)
        expect(data).to be_an(Array)
        expect(data.length).to eq(2)
      end

      it 'includes report metadata' do
        get '/api/reports'
        data = JSON.parse(last_response.body)

        report = data.first
        expect(report).to have_key('filename')
        expect(report).to have_key('created_at')
        expect(report).to have_key('issues_count')
        expect(report).to have_key('summary')
      end
    end
  end
end
