# frozen_string_literal: true

require 'pathname'

require_relative 'smartrails/version'
require_relative 'smartrails/audit_result'
require_relative 'smartrails/cli'

module SmartRails
  class Error < StandardError; end

  class << self
    def root
      @root ||= Pathname.new(File.expand_path('..', __dir__))
    end
  end
end
