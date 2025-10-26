# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'time'

RSpec.describe SmartRails::Reporters::JsonReporter do
  describe '#generate' do
    it 'writes an ISO8601 timestamp into the report' do
      reporter = described_class.new
      output_dir = Dir.mktmpdir
      @temp_dir = output_dir
      output_file = File.join(output_dir, 'report.json')

      reporter.generate([], output_file)

      report = JSON.parse(File.read(output_file))
      timestamp = report.fetch('timestamp')

      expect { Time.iso8601(timestamp) }.not_to raise_error
      expect(timestamp).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?[+-]\d{2}:?\d{2}/)
    end
  end
end
