# frozen_string_literal: true

RSpec.describe SmartRails do
  it 'has a version number' do
    expect(SmartRails::VERSION).not_to be nil
    expect(SmartRails::VERSION).to match(/\d+\.\d+\.\d+/)
  end

  describe '.root' do
    it 'returns the gem root directory' do
      expect(SmartRails.root).to be_a(Pathname)
      expect(SmartRails.root.to_s).to end_with('smartrails')
    end
  end
end