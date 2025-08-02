# frozen_string_literal: true

require_relative 'base_suggestor'
require 'net/http'
require 'json'
require 'uri'

module SmartRails
  module Suggestors
    class OpenAISuggestor < BaseSuggestor
      OPENAI_URL = 'https://api.openai.com/v1/chat/completions'

      def suggest(content)
        prompt = build_prompt(content)

        uri = URI.parse(OPENAI_URL)
        request = build_request(uri, prompt)

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        parse_response(response)
      end

      def check_connection
        return false unless ENV['OPENAI_API_KEY']

        uri = URI.parse(OPENAI_URL)
        request = build_request(uri, 'Hello')

        begin
          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5) do |http|
            http.request(request)
          end

          response.code == '200'
        rescue StandardError => e
          raise "Failed to connect to OpenAI: #{e.message}"
        end
      end

      protected

      def default_model
        ENV['OPENAI_MODEL'] || 'gpt-4'
      end

      private

      def build_request(uri, prompt)
        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{ENV.fetch('OPENAI_API_KEY', nil)}"
        request['Content-Type'] = 'application/json'
        request.body = JSON.dump({
                                   model: model,
                                   messages: [
                                     {
                                       role: 'system',
                                       content: 'You are a Ruby on Rails expert providing detailed code analysis and recommendations.'
                                     },
                                     {
                                       role: 'user',
                                       content: prompt
                                     }
                                   ],
                                   temperature: 0.7,
                                   max_tokens: 2000
                                 })
        request
      end

      def parse_response(response)
        if response.code == '200'
          json = JSON.parse(response.body)
          json.dig('choices', 0, 'message', 'content') || raise('No response content from OpenAI')
        else
          error_detail = begin
            JSON.parse(response.body)['error']['message']
          rescue StandardError
            response.body
          end
          raise "OpenAI API error: #{response.code} - #{error_detail}"
        end
      rescue JSON::ParserError => e
        raise "Failed to parse OpenAI response: #{e.message}"
      end
    end
  end
end
