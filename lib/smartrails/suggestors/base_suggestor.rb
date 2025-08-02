# frozen_string_literal: true

module SmartRails
  module Suggestors
    class BaseSuggestor
      attr_reader :model

      def initialize(model: nil)
        @model = model || default_model
      end

      def name
        self.class.name.split('::').last.gsub('Suggestor', '')
      end

      def suggest(content)
        raise NotImplementedError, "Subclasses must implement the suggest method"
      end

      def check_connection
        raise NotImplementedError, "Subclasses must implement the check_connection method"
      end

      protected

      def default_model
        raise NotImplementedError, "Subclasses must implement the default_model method"
      end

      def build_prompt(content)
        <<~PROMPT
          You are a Ruby on Rails expert assistant. Analyze the following code or report and provide:
          
          1. Security vulnerabilities and fixes
          2. Performance optimization suggestions
          3. Code quality improvements
          4. Rails best practices violations
          5. Potential bugs or issues
          
          Content to analyze:
          
          #{content}
          
          Please provide specific, actionable recommendations with code examples where appropriate.
        PROMPT
      end
    end
  end
end