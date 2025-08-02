# frozen_string_literal: true

require_relative 'smartrails/version'
require_relative 'smartrails/cli'

module SmartRails
  class Error < StandardError; end
  
  class << self
    def root
      @root ||= Pathname.new(File.expand_path('../..', __FILE__))
    end
  end
end