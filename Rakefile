# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

desc 'Run all quality checks'
task quality: [:rubocop, :spec]

task default: :quality

desc 'Open an irb session preloaded with SmartRails'
task :console do
  require 'irb'
  require 'irb/completion'
  require 'smartrails'

  ARGV.clear
  IRB.start
end

desc 'Generate YARD documentation'
task :doc do
  require 'yard'
  YARD::Rake::YardocTask.new
end

namespace :audit do
  desc 'Run SmartRails audit on itself'
  task :self do
    require_relative 'lib/smartrails'
    SmartRails::CLI.start(['audit', '--auto'])
  end
end
