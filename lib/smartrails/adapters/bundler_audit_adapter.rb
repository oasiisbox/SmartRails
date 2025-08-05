# frozen_string_literal: true

module SmartRails
  module Adapters
    class BundlerAuditAdapter < BaseAdapter
      CVE_SEVERITY_MAPPING = {
        'high' => :critical,
        'medium' => :high,
        'low' => :medium
      }.freeze

      def audit
        return [] unless command_available?('bundle-audit')
        
        begin
          # Update advisory database first
          update_result = run_command('bundle-audit update')
          Rails.logger.info "Advisory database updated" if defined?(Rails) && update_result[:success]
          
          # Run audit
          result = run_command('bundle-audit check --format json')
          
          if result[:success] && result[:output].strip.empty?
            # No vulnerabilities found
            return []
          elsif !result[:success] && result[:output].include?('"results"')
            # Vulnerabilities found (exit code 1 is expected)
            data = parse_json(result[:output])
            return format_results(data)
          elsif result[:output].include?('Vulnerabilities found!')
            # Fallback to text parsing if JSON not available
            return parse_text_output(result[:output])
          else
            Rails.logger.error "Unexpected bundle-audit output: #{result[:output]}" if defined?(Rails)
            return []
          end
        rescue StandardError => e
          Rails.logger.error "bundler-audit error: #{e.message}" if defined?(Rails)
          []
        end
      end

      def auto_fix(issues)
        fixes_applied = []
        
        # Group issues by gem for efficient updating
        issues_by_gem = issues.group_by { |issue| issue[:metadata][:gem_name] }
        
        issues_by_gem.each do |gem_name, gem_issues|
          fix_result = attempt_gem_update(gem_name, gem_issues)
          fixes_applied << fix_result if fix_result[:success]
        end
        
        fixes_applied
      end

      private

      def format_results(data)
        issues = []
        
        return issues unless data['results']
        
        data['results'].each do |result|
          case result['type']
          when 'InsecureSource'
            issues << create_insecure_source_issue(result)
          when 'UnpatchedGem'
            issues << create_unpatched_gem_issue(result)
          end
        end
        
        issues
      end

      def create_insecure_source_issue(result)
        create_issue(
          type: :security,
          severity: :high,
          category: :security,
          message: "Insecure gem source detected: #{result['source']}",
          file: 'Gemfile',
          line: nil,
          remediation: 'Replace insecure gem source with HTTPS equivalent',
          auto_fixable: true,
          fix_command: "Replace #{result['source']} with secure HTTPS source",
          documentation_url: 'https://bundler.io/guides/gemfile_security.html',
          metadata: {
            source: result['source'],
            issue_type: 'insecure_source'
          }
        )
      end

      def create_unpatched_gem_issue(result)
        gem_info = result['gem']
        advisory = result['advisory']
        
        severity = determine_cve_severity(advisory)
        
        create_issue(
          type: :security,
          severity: severity,
          category: :security,
          message: "#{gem_info['name']} #{gem_info['version']} has known vulnerability: #{advisory['title']}",
          file: 'Gemfile.lock',
          line: nil,
          remediation: generate_gem_remediation(gem_info, advisory),
          auto_fixable: can_auto_update_gem?(gem_info, advisory),
          fix_command: "bundle update #{gem_info['name']}",
          documentation_url: advisory['url'],
          metadata: {
            gem_name: gem_info['name'],
            gem_version: gem_info['version'],
            advisory_id: advisory['id'],
            cve: advisory['cve'],
            cvss: advisory['cvss_v3'],
            patched_versions: advisory['patched_versions'],
            unaffected_versions: advisory['unaffected_versions'],
            issue_type: 'vulnerable_gem'
          }
        )
      end

      def parse_text_output(output)
        issues = []
        lines = output.split("\n")
        
        current_gem = nil
        lines.each do |line|
          if line.match(/Name: (.+)/)
            current_gem = { name: $1 }
          elsif line.match(/Version: (.+)/) && current_gem
            current_gem[:version] = $1
          elsif line.match(/Advisory: (.+)/) && current_gem
            current_gem[:advisory] = $1
          elsif line.match(/Criticality: (.+)/) && current_gem
            current_gem[:criticality] = $1
          elsif line.match(/URL: (.+)/) && current_gem
            current_gem[:url] = $1
            
            # Create issue when we have complete info
            issues << create_issue(
              type: :security,
              severity: map_criticality_to_severity(current_gem[:criticality]),
              category: :security,
              message: "#{current_gem[:name]} #{current_gem[:version]} has vulnerability #{current_gem[:advisory]}",
              file: 'Gemfile.lock',
              remediation: "Update #{current_gem[:name]} to a patched version",
              auto_fixable: true,
              fix_command: "bundle update #{current_gem[:name]}",
              documentation_url: current_gem[:url],
              metadata: {
                gem_name: current_gem[:name],
                gem_version: current_gem[:version],
                advisory_id: current_gem[:advisory],
                issue_type: 'vulnerable_gem'
              }
            )
            
            current_gem = nil
          end
        end
        
        issues
      end

      def determine_cve_severity(advisory)
        # Use CVSS score if available
        if advisory['cvss_v3']
          cvss_score = advisory['cvss_v3'].to_f
          return :critical if cvss_score >= 9.0
          return :high if cvss_score >= 7.0
          return :medium if cvss_score >= 4.0
          return :low
        end
        
        # Fallback to criticality
        map_criticality_to_severity(advisory['criticality'])
      end

      def map_criticality_to_severity(criticality)
        case criticality&.downcase
        when 'critical', 'high'
          :critical
        when 'medium'
          :high
        when 'low'
          :medium
        else
          :medium
        end
      end

      def generate_gem_remediation(gem_info, advisory)
        if advisory['patched_versions'] && !advisory['patched_versions'].empty?
          "Update #{gem_info['name']} to version #{advisory['patched_versions'].first} or later"
        elsif advisory['unaffected_versions'] && !advisory['unaffected_versions'].empty?
          "Update #{gem_info['name']} to an unaffected version: #{advisory['unaffected_versions'].join(', ')}"
        else
          "Update #{gem_info['name']} to the latest version or find an alternative gem"
        end
      end

      def can_auto_update_gem?(gem_info, advisory)
        # Only auto-update if there are patched versions available
        !!(advisory['patched_versions'] && !advisory['patched_versions'].empty?)
      end

      def attempt_gem_update(gem_name, gem_issues)
        # Check if gem is in Gemfile (vs being a dependency)
        gemfile_content = read_file('Gemfile')
        direct_dependency = gemfile_content.include?("gem '#{gem_name}'") || 
                           gemfile_content.include?("gem \"#{gem_name}\"")
        
        if direct_dependency
          # Try to update the gem
          result = run_command("bundle update #{gem_name}")
          
          if result[:success]
            {
              success: true,
              description: "Updated #{gem_name} to address security vulnerabilities",
              files_modified: ['Gemfile.lock'],
              gem_updated: gem_name,
              issues_addressed: gem_issues.size
            }
          else
            {
              success: false,
              reason: "Failed to update #{gem_name}: #{result[:output]}",
              suggestion: "Try updating manually or check for version constraints in Gemfile"
            }
          end
        else
          {
            success: false,
            reason: "#{gem_name} is an indirect dependency",
            suggestion: "Update the parent gem that depends on #{gem_name}"
          }
        end
      end

      def update_advisory_database
        result = run_command('bundle-audit update')
        unless result[:success]
          Rails.logger.warn "Could not update advisory database: #{result[:output]}" if defined?(Rails)
        end
      end
    end
  end
end