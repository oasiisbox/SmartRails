# frozen_string_literal: true

module SmartRails
  module Adapters
    class BrakemanAdapter < BaseAdapter
      AUTO_FIXABLE_TYPES = [
        'Cross-Site Request Forgery',
        'Mass Assignment',
        'SSL Verification Bypass',
        'Unsafe Reflection',
        'Weak Hash'
      ].freeze

      REMEDIATION_TEMPLATES = {
        'Cross-Site Request Forgery' => 'Add `protect_from_forgery with: :exception` to ApplicationController',
        'Mass Assignment' => 'Use strong parameters in controller actions',
        'SSL Verification Bypass' => 'Remove `verify_mode = VERIFY_NONE` and use proper SSL verification',
        'Unsafe Reflection' => 'Validate user input before using with `const_get` or similar methods',
        'Weak Hash' => 'Use SHA-256 or stronger hash algorithms instead of MD5/SHA1'
      }.freeze

      def audit
        return [] unless gem_available?('brakeman')
        
        require 'brakeman'
        
        begin
          # Configure Brakeman options
          options = {
            app_path: @project_path,
            quiet: true,
            ignore_file: ignore_file_path,
            assume_all_routes: false,
            skip_checks: skip_checks
          }
          
          # Run Brakeman scan
          tracker = Brakeman.run(options)
          
          # Format results
          format_results(tracker)
        rescue StandardError => e
          Rails.logger.error "Brakeman error: #{e.message}" if defined?(Rails)
          []
        end
      end

      def auto_fix(issues)
        fixes_applied = []
        
        issues.each do |issue|
          next unless issue[:auto_fixable]
          
          fix_result = apply_auto_fix(issue)
          fixes_applied << fix_result if fix_result[:success]
        end
        
        fixes_applied
      end

      private

      def format_results(tracker)
        issues = []
        
        # Security warnings
        tracker.warnings.each do |warning|
          issues << create_issue(
            type: :security,
            severity: severity_mapping(warning.confidence),
            category: :security,
            message: warning.message,
            file: relative_path(warning.file.absolute),
            line: warning.line,
            fingerprint: warning.fingerprint,
            remediation: REMEDIATION_TEMPLATES[warning.warning_type] || 
                        "Review #{warning.warning_type} vulnerability",
            auto_fixable: AUTO_FIXABLE_TYPES.include?(warning.warning_type),
            fix_command: generate_fix_command(warning),
            documentation_url: documentation_url(warning.warning_type),
            metadata: {
              warning_type: warning.warning_type,
              confidence: warning.confidence,
              check_name: warning.check_name,
              code: warning.format_code
            }
          )
        end
        
        # Controller warnings
        tracker.controller_warnings.each do |warning|
          issues << create_issue(
            type: :security,
            severity: severity_mapping(warning.confidence),
            category: :security,
            message: "Controller: #{warning.message}",
            file: relative_path(warning.file.absolute),
            line: warning.line,
            remediation: REMEDIATION_TEMPLATES[warning.warning_type] || 
                        "Review controller #{warning.warning_type}",
            auto_fixable: AUTO_FIXABLE_TYPES.include?(warning.warning_type),
            metadata: {
              warning_type: warning.warning_type,
              controller: warning.controller,
              method: warning.method
            }
          )
        end
        
        # Model warnings
        tracker.model_warnings.each do |warning|
          issues << create_issue(
            type: :security,
            severity: severity_mapping(warning.confidence),
            category: :security,
            message: "Model: #{warning.message}",
            file: relative_path(warning.file.absolute),
            line: warning.line,
            remediation: REMEDIATION_TEMPLATES[warning.warning_type] || 
                        "Review model #{warning.warning_type}",
            auto_fixable: AUTO_FIXABLE_TYPES.include?(warning.warning_type),
            metadata: {
              warning_type: warning.warning_type,
              model: warning.model
            }
          )
        end
        
        issues
      end

      def severity_mapping(confidence)
        case confidence
        when 0 then :critical
        when 1 then :high
        when 2 then :medium
        else :low
        end
      end

      def apply_auto_fix(issue)
        case issue[:metadata][:warning_type]
        when 'Cross-Site Request Forgery'
          fix_csrf_protection(issue)
        when 'Mass Assignment'
          fix_mass_assignment(issue)
        when 'SSL Verification Bypass'
          fix_ssl_verification(issue)
        else
          { success: false, reason: 'Auto-fix not implemented for this issue type' }
        end
      end

      def fix_csrf_protection(issue)
        controller_file = File.join(@project_path, 'app/controllers/application_controller.rb')
        return { success: false, reason: 'ApplicationController not found' } unless File.exist?(controller_file)
        
        content = File.read(controller_file)
        
        # Check if protection already exists
        return { success: false, reason: 'CSRF protection already exists' } if content.include?('protect_from_forgery')
        
        # Add protection after class definition
        new_content = content.sub(
          /class ApplicationController.*$/,
          "\\0\n  protect_from_forgery with: :exception\n"
        )
        
        File.write(controller_file, new_content)
        
        {
          success: true,
          description: 'Added CSRF protection to ApplicationController',
          files_modified: ['app/controllers/application_controller.rb']
        }
      end

      def fix_mass_assignment(issue)
        # This is complex and context-dependent, so we'll provide guidance instead
        {
          success: false,
          reason: 'Mass assignment requires manual review - implement strong parameters',
          guidance: 'Convert attr_accessible to strong parameters in controller actions'
        }
      end

      def fix_ssl_verification(issue)
        file_path = File.join(@project_path, issue[:file])
        return { success: false, reason: 'File not found' } unless File.exist?(file_path)
        
        content = File.read(file_path)
        
        # Remove dangerous SSL bypass patterns
        patterns_to_remove = [
          /\.verify_mode\s*=\s*OpenSSL::SSL::VERIFY_NONE/,
          /OpenSSL::SSL::VERIFY_NONE/,
          /verify_mode.*VERIFY_NONE/
        ]
        
        modified = false
        patterns_to_remove.each do |pattern|
          if content.match?(pattern)
            content.gsub!(pattern, '# SSL verification enabled for security')
            modified = true
          end
        end
        
        if modified
          File.write(file_path, content)
          {
            success: true,
            description: 'Removed SSL verification bypass',
            files_modified: [issue[:file]]
          }
        else
          { success: false, reason: 'SSL bypass pattern not found or already fixed' }
        end
      end

      def generate_fix_command(warning)
        case warning.warning_type
        when 'Cross-Site Request Forgery'
          "Add 'protect_from_forgery with: :exception' to ApplicationController"
        when 'Mass Assignment'
          "Implement strong parameters in #{warning.file}:#{warning.line}"
        else
          nil
        end
      end

      def documentation_url(warning_type)
        base_url = 'https://brakemanscanner.org/docs/warning_types'
        slug = warning_type.downcase.gsub(/[^a-z0-9]/, '_').gsub(/__+/, '_')
        "#{base_url}/#{slug}/"
      end

      def ignore_file_path
        ignore_file = File.join(@project_path, '.brakeman.ignore')
        File.exist?(ignore_file) ? ignore_file : nil
      end

      def skip_checks
        # Skip checks that are handled by other tools or not relevant
        []
      end
    end
  end
end