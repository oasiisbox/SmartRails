# frozen_string_literal: true

require_relative 'base'
require_relative '../suggestors/ollama_suggestor'
require_relative '../suggestors/openai_suggestor'

module SmartRails
  module Commands
    class Suggest < Base
      def execute(source = nil)
        content = get_content(source)
        return unless content

        suggestor = create_suggestor
        say "💬 Sending to #{suggestor.name}...", :yellow

        begin
          response = suggestor.suggest(content)
          save_suggestion(response)
          display_suggestion(response)
        rescue StandardError => e
          say "❌ Error: #{e.message}", :red
          say '💡 Make sure the LLM service is running and configured correctly', :yellow
        end
      end

      def check_connection
        suggestor = create_suggestor
        say "🔌 Checking connection to #{suggestor.name}...", :yellow

        begin
          if suggestor.check_connection
            say '✅ Connection successful!', :green
          else
            say '❌ Connection failed', :red
          end
        rescue StandardError => e
          say "❌ Error: #{e.message}", :red
        end
      end

      private

      def get_content(source)
        if options[:file]
          unless File.exist?(options[:file])
            say "❌ File not found: #{options[:file]}", :red
            return nil
          end
          File.read(options[:file])
        elsif source
          source
        else
          # Try to use latest audit report
          latest_report = Dir.glob(reports_dir.join('audit_*.json')).max_by { |f| File.mtime(f) }
          if latest_report
            say "📊 Using latest audit report: #{File.basename(latest_report)}", :blue
            File.read(latest_report)
          else
            say '❌ Please provide content, use --file, or run an audit first', :red
            nil
          end
        end
      end

      def create_suggestor
        case options[:llm].downcase
        when 'openai'
          Suggestors::OpenAISuggestor.new(model: options[:model])
        else
          Suggestors::OllamaSuggestor.new(model: options[:model])
        end
      end

      def save_suggestion(response)
        timestamp = Time.now.to_i

        # Save as text
        text_file = reports_dir.join("suggestion_#{timestamp}.txt")
        text_file.write(response)

        # Save as markdown
        md_file = reports_dir.join("suggestion_#{timestamp}.md")
        md_content = "# AI Suggestion Report\n\n"
        md_content << "**Generated at:** #{Time.now}\n"
        md_content << "**Model:** #{options[:llm]}\n\n"
        md_content << "## Suggestion\n\n#{response}"
        md_file.write(md_content)
      end

      def display_suggestion(response)
        say "\n🧠 AI Suggestion:", :green
        say '─' * 50, :blue
        say response
        say '─' * 50, :blue
      end
    end
  end
end
