# frozen_string_literal: true

require 'bundler/setup'
require 'simplecov'

# Start SimpleCov before requiring the main library
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
  add_filter '/bin/'

  add_group 'Auditors', 'lib/smartrails/auditors'
  add_group 'Commands', 'lib/smartrails/commands'
  add_group 'Reporters', 'lib/smartrails/reporters'
  add_group 'Suggestors', 'lib/smartrails/suggestors'

  minimum_coverage 85
end

require 'smartrails'
require 'rspec'
require 'tempfile'
require 'tmpdir'
require 'fileutils'

# Load support files
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  # Use expect syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Filter lines from Rails gems in backtraces
  config.filter_gems_from_backtrace 'thor', 'sinatra', 'tty-prompt'

  # Use documentation format for verbose output
  config.formatter = :documentation if ENV['VERBOSE']

  # Clean up temporary files after each test
  config.after do
    # Clean up any temporary directories created during tests
    FileUtils.rm_rf(@temp_dir) if defined?(@temp_dir) && @temp_dir && Dir.exist?(@temp_dir)
  end

  # Shared context for creating temporary Rails project structures
  config.include SpecHelpers::RailsProjectHelper
  config.include SpecHelpers::FileSystemHelper
  config.include SpecHelpers::AuditorHelper
end
