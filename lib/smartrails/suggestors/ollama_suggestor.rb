# frozen_string_literal: true

require_relative 'base_suggestor'
require 'net/http'
require 'json'
require 'uri'

module SmartRails
  module Suggestors
    class OllamaSuggestor < BaseSuggestor
      OLLAMA_URL = 'http://localhost:11434'

      def suggest(content)
        prompt = build_prompt(content)

        uri = URI.parse("#{OLLAMA_URL}/api/generate")
        request = build_request(uri, prompt)

        response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request(request)
        end

        parse_response(response)
      end

      def check_connection
        uri = URI.parse("#{OLLAMA_URL}/api/generate")
        request = build_request(uri, 'Hello, are you there?')

        begin
          response = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 5, read_timeout: 10) do |http|
            http.request(request)
          end

          response.code == '200' && JSON.parse(response.body)['response'].to_s.strip != ''
        rescue StandardError => e
          raise "Failed to connect to Ollama: #{e.message}"
        end
      end

      protected

      def default_model
        ENV['OLLAMA_MODEL'] || 'llama3'
      end

      private

      def build_request(uri, prompt)
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request.body = JSON.dump({
                                   model: model,
                                   prompt: prompt,
                                   stream: false,
                                   options: {
                                     temperature: 0.7,
                                     top_p: 0.9
                                   }
                                 })
        request
      end

      def parse_response(response)
        raise "Ollama API error: #{response.code} - #{response.body}" unless response.code == '200'

        json = JSON.parse(response.body)
        json['response'] || raise('No response content from Ollama')
      rescue JSON::ParserError => e
        raise "Failed to parse Ollama response: #{e.message}"
      end
    end
  end
end
