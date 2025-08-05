# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/fix_manager'

RSpec.describe SmartRails::FixManager, 'Debug Safe Fix Detection' do
  let(:project_path) { create_temp_rails_project }
  let(:fix_manager) { described_class.new(project_path) }
  
  it 'correctly identifies safe RuboCop fixes' do
    safe_issue = {
      tool: :rubocop,
      type: :quality,
      severity: :low,
      message: 'Use single quotes for string literals',
      file: 'app/models/test_model.rb',
      line: 1,
      auto_fixable: true,
      fix_command: 'bundle exec rubocop --auto-correct --only Style/StringLiterals app/models/test_model.rb',
      metadata: { cop_name: 'Style/StringLiterals' }
    }
    
    # Debug the safe_fix? method
    puts "Issue tool: #{safe_issue[:tool]}"
    puts "Issue metadata: #{safe_issue[:metadata]}"
    puts "SAFE_FIX_TYPES includes #{safe_issue[:tool]}? #{SmartRails::FixManager::SAFE_FIX_TYPES.include?(safe_issue[:tool])}"
    puts "SAFE_CATEGORIES includes cop_name? #{SmartRails::FixManager::SAFE_CATEGORIES.include?(safe_issue[:metadata][:cop_name])}"
    puts "SAFE_CATEGORIES: #{SmartRails::FixManager::SAFE_CATEGORIES}"
    
    # Test the method directly
    is_safe = fix_manager.send(:safe_fix?, safe_issue)
    puts "Is safe fix? #{is_safe}"
    
    expect(is_safe).to be true
  end
  
  it 'categorizes fixes correctly' do
    safe_issue = {
      tool: :rubocop,
      metadata: { cop_name: 'Style/StringLiterals' }
    }
    
    risky_issue = {
      tool: :brakeman,
      metadata: { warning_type: 'Cross-Site Request Forgery' }
    }
    
    safe_fixes, risky_fixes = fix_manager.send(:categorize_fixes, [safe_issue, risky_issue])
    
    puts "Safe fixes: #{safe_fixes}"
    puts "Risky fixes: #{risky_fixes}"
    
    expect(safe_fixes).to include(safe_issue)
    expect(risky_fixes).to include(risky_issue)
  end
end