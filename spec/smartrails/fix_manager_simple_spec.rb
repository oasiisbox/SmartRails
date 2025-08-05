# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/fix_manager'

RSpec.describe SmartRails::FixManager, 'Simple Auto-Apply Test' do
  let(:project_path) { create_temp_rails_project }
  let(:fix_manager) { described_class.new(project_path) }
  
  it 'auto-applies safe fixes without prompting' do
    safe_issue = {
      tool: :rubocop,
      type: :quality,
      severity: :low,
      message: 'Use single quotes for string literals',
      file: 'app/models/test_model.rb',
      line: 1,
      auto_fixable: true,
      fix_command: 'echo "Simulated RuboCop fix applied"',
      metadata: { cop_name: 'Style/StringLiterals' }
    }
    
    # Mock the prompt to verify it's not called for safe fixes
    allow(fix_manager).to receive(:confirm_safe_fixes).and_return(true)
    allow(fix_manager).to receive(:confirm_risky_fix).and_return(false)
    
    # Mock validation methods to pass
    allow(fix_manager).to receive(:validate_project_integrity).and_return(true)
    allow(fix_manager).to receive(:validate_syntax).and_return(true)
    allow(fix_manager).to receive(:validate_rails_app).and_return(true)
    
    # Mock adapter loading and execution
    mock_adapter = double('RubocopAdapter')
    allow(mock_adapter).to receive(:auto_fix).with([safe_issue]).and_return([{
      success: true,
      description: 'Applied RuboCop fix for Style/StringLiterals',
      files_modified: ['app/models/test_model.rb'],
      fix_applied: 'Style/StringLiterals'
    }])
    allow(fix_manager).to receive(:load_adapter_for_issue).with(safe_issue).and_return(mock_adapter)
    
    result = fix_manager.apply_fixes([safe_issue], { auto_apply_safe: true })
    
    # With auto_apply_safe: true, confirm_safe_fixes should not be called
    expect(fix_manager).not_to have_received(:confirm_safe_fixes)
    expect(fix_manager).not_to have_received(:confirm_risky_fix)
    
    expect(result[:fixes]).not_to be_empty
    expect(result[:errors]).to be_empty
  end
  
  it 'treats unknown fixes as risky by default' do
    risky_issue = {
      tool: :unknown_tool,
      type: :security,
      severity: :high,
      message: 'Unknown security issue',
      file: 'app/controllers/application_controller.rb',
      auto_fixable: true,
      fix_command: 'echo "Simulated risky fix"',
      metadata: { some_field: 'some_value' }
    }
    
    # Mock prompts - this should be called for risky fixes
    allow(fix_manager).to receive(:confirm_risky_fix).and_return(false)
    
    result = fix_manager.apply_fixes([risky_issue], { auto_apply_safe: true })
    
    # Should prompt for risky fix
    expect(fix_manager).to have_received(:confirm_risky_fix).with(risky_issue)
    
    # Should not apply any fixes because user declined
    expect(result[:fixes]).to be_empty
  end
end