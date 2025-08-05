# frozen_string_literal: true

require 'spec_helper'
require 'smartrails/adapters/brakeman_adapter'

RSpec.describe SmartRails::Adapters::BrakemanAdapter do
  let(:project_path) { create_temp_rails_project }
  let(:adapter) { described_class.new(project_path) }
  
  describe '#audit' do
    context 'when Brakeman gem is not available' do
      before do
        allow(adapter).to receive(:gem_available?).with('brakeman').and_return(false)
      end
      
      it 'returns empty array' do
        expect(adapter.audit).to eq([])
      end
    end
    
    context 'when Brakeman gem is available' do
      before do
        allow(adapter).to receive(:gem_available?).with('brakeman').and_return(true)
      end
      
      context 'when Brakeman execution fails' do
        before do
          # Mock Brakeman to raise an error
          allow(adapter).to receive(:require).with('brakeman').and_raise(StandardError.new('Brakeman error'))
        end
        
        it 'returns empty array and logs error' do
          expect(adapter.audit).to eq([])
        end
      end
      
      context 'when Brakeman runs successfully' do
        let(:mock_tracker) { double('Brakeman::Tracker') }
        let(:mock_warning) { double('Brakeman::Warning') }
        
        before do
          allow(adapter).to receive(:require).with('brakeman')
          
          # Mock Brakeman module and run method
          brakeman_module = Module.new
          allow(brakeman_module).to receive(:run).and_return(mock_tracker)
          stub_const('Brakeman', brakeman_module)
          
          # Mock tracker methods
          allow(mock_tracker).to receive(:warnings).and_return([mock_warning])
          allow(mock_tracker).to receive(:controller_warnings).and_return([])
          allow(mock_tracker).to receive(:model_warnings).and_return([])
          
          # Mock warning properties
          allow(mock_warning).to receive_messages(
            message: 'CSRF protection not found',
            warning_type: 'Cross-Site Request Forgery',
            confidence: 0,
            check_name: 'CheckForCSRF',
            fingerprint: 'test_fingerprint_123',
            line: 10,
            format_code: 'ApplicationController'
          )
          
          # Mock file object
          mock_file = double('file')
          allow(mock_file).to receive(:absolute).and_return("#{project_path}/app/controllers/application_controller.rb")
          allow(mock_warning).to receive(:file).and_return(mock_file)
        end
        
        it 'returns formatted issues' do
          issues = adapter.audit
          
          expect(issues).to be_an(Array)
          expect(issues.size).to eq(1)
          
          issue = issues.first
          expect(issue[:tool]).to eq(:brakeman)
          expect(issue[:type]).to eq(:security)
          expect(issue[:severity]).to eq(:critical)
          expect(issue[:message]).to eq('CSRF protection not found')
          expect(issue[:file]).to eq('app/controllers/application_controller.rb')
          expect(issue[:line]).to eq(10)
          expect(issue[:auto_fixable]).to be true
          expect(issue[:metadata][:warning_type]).to eq('Cross-Site Request Forgery')
        end
      end
    end
  end
  
  describe '#severity_mapping' do
    it 'maps Brakeman confidence levels to severity' do
      expect(adapter.send(:severity_mapping, 0)).to eq(:critical)
      expect(adapter.send(:severity_mapping, 1)).to eq(:high)
      expect(adapter.send(:severity_mapping, 2)).to eq(:medium)
      expect(adapter.send(:severity_mapping, 3)).to eq(:low)
      expect(adapter.send(:severity_mapping, 99)).to eq(:low)
    end
  end
  
  describe '#auto_fix' do
    let(:csrf_issue) do
      {
        auto_fixable: true,
        metadata: { warning_type: 'Cross-Site Request Forgery' },
        file: 'app/controllers/application_controller.rb'
      }
    end
    
    let(:mass_assignment_issue) do
      {
        auto_fixable: true,
        metadata: { warning_type: 'Mass Assignment' },
        file: 'app/controllers/users_controller.rb'
      }
    end
    
    let(:non_fixable_issue) do
      {
        auto_fixable: false,
        metadata: { warning_type: 'SQL Injection' }
      }
    end
    
    before do
      # Create application controller file
      create_rails_controller(project_path, 'application', <<~RUBY)
        class ApplicationController < ActionController::Base
        end
      RUBY
    end
    
    it 'applies fixes to fixable issues' do
      allow(adapter).to receive(:apply_auto_fix).with(csrf_issue).and_return({ success: true })
      
      fixes = adapter.auto_fix([csrf_issue, non_fixable_issue])
      
      expect(fixes.size).to eq(1)
      expect(fixes.first[:success]).to be true
    end
    
    it 'skips non-fixable issues' do
      fixes = adapter.auto_fix([non_fixable_issue])
      
      expect(fixes).to be_empty
    end
  end
  
  describe '#fix_csrf_protection' do
    let(:issue) { { file: 'app/controllers/application_controller.rb' } }
    
    context 'when ApplicationController exists without CSRF protection' do
      before do
        create_rails_controller(project_path, 'application', <<~RUBY)
          class ApplicationController < ActionController::Base
          end
        RUBY
      end
      
      it 'adds CSRF protection' do
        result = adapter.send(:fix_csrf_protection, issue)
        
        expect(result[:success]).to be true
        expect(result[:description]).to include('Added CSRF protection')
        expect(result[:files_modified]).to include('app/controllers/application_controller.rb')
        
        # Verify the fix was applied
        controller_content = File.read(File.join(project_path, 'app/controllers/application_controller.rb'))
        expect(controller_content).to include('protect_from_forgery with: :exception')
      end
    end
    
    context 'when CSRF protection already exists' do
      before do
        create_rails_controller(project_path, 'application', <<~RUBY)
          class ApplicationController < ActionController::Base
            protect_from_forgery with: :exception
          end
        RUBY
      end
      
      it 'does not add duplicate protection' do
        result = adapter.send(:fix_csrf_protection, issue)
        
        expect(result[:success]).to be false
        expect(result[:reason]).to include('already exists')
      end
    end
    
    context 'when ApplicationController does not exist' do
      it 'returns failure' do
        result = adapter.send(:fix_csrf_protection, issue)
        
        expect(result[:success]).to be false
        expect(result[:reason]).to include('not found')
      end
    end
  end
  
  describe '#fix_mass_assignment' do
    let(:issue) { { file: 'app/controllers/users_controller.rb' } }
    
    it 'returns guidance instead of automatic fix' do
      result = adapter.send(:fix_mass_assignment, issue)
      
      expect(result[:success]).to be false
      expect(result[:reason]).to include('requires manual review')
      expect(result[:guidance]).to include('strong parameters')
    end
  end
  
  describe '#fix_ssl_verification' do
    let(:issue) { { file: 'lib/http_client.rb' } }
    
    context 'when file contains SSL bypass' do
      before do
        file_path = File.join(project_path, 'lib/http_client.rb')
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, <<~RUBY)
          require 'net/http'
          
          http = Net::HTTP.new(host, port)
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          http.use_ssl = true
        RUBY
      end
      
      it 'removes SSL bypass patterns' do
        result = adapter.send(:fix_ssl_verification, issue)
        
        expect(result[:success]).to be true
        expect(result[:description]).to include('Removed SSL verification bypass')
        expect(result[:files_modified]).to include('lib/http_client.rb')
        
        # Verify the fix was applied
        file_content = File.read(File.join(project_path, 'lib/http_client.rb'))
        expect(file_content).not_to include('VERIFY_NONE')
        expect(file_content).to include('SSL verification enabled for security')
      end
    end
    
    context 'when file does not contain SSL bypass' do
      before do
        file_path = File.join(project_path, 'lib/http_client.rb')
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, <<~RUBY)
          require 'net/http'
          
          http = Net::HTTP.new(host, port)
          http.use_ssl = true
        RUBY
      end
      
      it 'returns failure when no patterns found' do
        result = adapter.send(:fix_ssl_verification, issue)
        
        expect(result[:success]).to be false
        expect(result[:reason]).to include('pattern not found')
      end
    end
    
    context 'when file does not exist' do
      it 'returns failure' do
        result = adapter.send(:fix_ssl_verification, issue)
        
        expect(result[:success]).to be false
        expect(result[:reason]).to include('File not found')
      end
    end
  end
  
  describe '#generate_fix_command' do
    let(:csrf_warning) { double(warning_type: 'Cross-Site Request Forgery') }
    let(:mass_assignment_warning) do 
      double(
        warning_type: 'Mass Assignment',
        file: 'app/controllers/users_controller.rb',
        line: 15
      )
    end
    let(:other_warning) { double(warning_type: 'SQL Injection') }
    
    it 'generates command for CSRF protection' do
      command = adapter.send(:generate_fix_command, csrf_warning)
      expect(command).to include('protect_from_forgery')
    end
    
    it 'generates command for mass assignment' do
      command = adapter.send(:generate_fix_command, mass_assignment_warning)
      expect(command).to include('strong parameters')
      expect(command).to include('users_controller.rb:15')
    end
    
    it 'returns nil for unsupported warning types' do
      command = adapter.send(:generate_fix_command, other_warning)
      expect(command).to be_nil
    end
  end
  
  describe '#documentation_url' do
    it 'generates correct documentation URLs' do
      url = adapter.send(:documentation_url, 'Cross-Site Request Forgery')
      expect(url).to include('brakemanscanner.org/docs/warning_types')
      expect(url).to include('cross_site_request_forgery')
    end
    
    it 'handles warning types with special characters' do
      url = adapter.send(:documentation_url, 'Mass Assignment')
      expect(url).to include('mass_assignment')
    end
  end
  
  describe 'constants' do
    it 'defines auto-fixable types' do
      expect(described_class::AUTO_FIXABLE_TYPES).to include(
        'Cross-Site Request Forgery',
        'Mass Assignment',
        'SSL Verification Bypass'
      )
    end
    
    it 'defines remediation templates' do
      expect(described_class::REMEDIATION_TEMPLATES).to have_key('Cross-Site Request Forgery')
      expect(described_class::REMEDIATION_TEMPLATES['Cross-Site Request Forgery']).to include('protect_from_forgery')
    end
  end
end