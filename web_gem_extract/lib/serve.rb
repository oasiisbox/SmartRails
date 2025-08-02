# frozen_string_literal: true

require_relative 'base'
require 'sinatra/base'
require 'json'

module SmartRails
  module Commands
    class Serve < Base
      def execute
        ensure_directories

        say '🌐 Starting SmartRails web interface...', :green
        say "📍 URL: http://#{options[:host]}:#{options[:port]}", :blue
        say 'Press Ctrl+C to stop', :yellow

        app = create_app
        app.run!
      end

      private

      def create_app
        reports_path = reports_dir

        Class.new(Sinatra::Base) do
          set :port, options[:port]
          set :bind, options[:host]
          set :public_folder, reports_path
          set :views, File.expand_path('../../views', __dir__)

          get '/' do
            @reports = Dir.glob(File.join(reports_path, 'audit_*.json'))
              .sort_by { |f| File.mtime(f) }
              .reverse
              .map do |file|
              {
                filename: File.basename(file),
                created_at: File.mtime(file),
                size: File.size(file),
                html_exists: File.exist?(file.sub('.json', '.html'))
              }
            end

            erb :index
          end

          get '/report/:filename' do
            file_path = File.join(reports_path, params[:filename])
            halt 404 unless File.exist?(file_path)

            if params[:filename].end_with?('.json')
              content_type :json
            elsif params[:filename].end_with?('.html')
              content_type :html
            end

            send_file file_path
          end

          get '/api/reports' do
            content_type :json

            reports = Dir.glob(File.join(reports_path, 'audit_*.json')).map do |file|
              data = JSON.parse(File.read(file))
              {
                filename: File.basename(file),
                created_at: File.mtime(file),
                issues_count: data['issues']&.count || 0,
                summary: data['summary']
              }
            end

            reports.to_json
          end
        end
      end
    end
  end
end
