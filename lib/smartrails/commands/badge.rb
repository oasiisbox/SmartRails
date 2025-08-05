# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'colorize'

require_relative 'base'

module SmartRails
  module Commands
    class Badge < Base
      def initialize(options)
        super(options)
        @project_path = options[:project_path] || Dir.pwd
        @verbose = options[:verbose]
      end

      def execute
        puts "🏆 SmartRails Quality Badge Generator".blue.bold
        puts "=" * 50

        # Load audit results
        audit_results = load_audit_results
        unless audit_results
          puts "❌ No audit results found. Run 'smartrails audit' first.".red
          return false
        end

        # Generate badge
        badge_data = generate_badge(audit_results)
        
        # Display badge information
        display_badge_info(badge_data)
        
        # Save badge data
        save_badge_data(badge_data) unless @options[:format] == 'display_only'
        
        # Update README if requested
        update_readme(badge_data) if @options[:update_readme]
        
        true
      end

      private

      def load_audit_results
        # Look for audit results file
        audit_file = @options[:audit_file]
        
        unless audit_file
          # Look for recent audit results
          reports_dir = File.join(@project_path, 'tmp', 'smartrails_reports')
          
          potential_files = [
            File.join(reports_dir, 'smartrails_audit.json'),
            File.join(reports_dir, 'audit_results.json')
          ]
          
          audit_file = potential_files.find { |f| File.exist?(f) }
        end
        
        unless audit_file && File.exist?(audit_file)
          return nil
        end

        begin
          JSON.parse(File.read(audit_file), symbolize_names: true)
        rescue JSON::ParserError => e
          puts "❌ Failed to parse audit results: #{e.message}".red if @verbose
          nil
        end
      end

      def generate_badge(audit_results)
        # Extract score from audit results
        global_score = if audit_results[:score]
                        audit_results[:score][:global] || audit_results[:score][:overall] || 50
                      else
                        calculate_score_from_issues(audit_results)
                      end

        # Determine badge level
        level = determine_badge_level(global_score)
        
        {
          level: level,
          score: global_score,
          color: badge_color(level),
          text_color: text_color(level),
          project_name: File.basename(@project_path),
          generated_at: Time.now.iso8601,
          audit_summary: extract_audit_summary(audit_results)
        }
      end

      def calculate_score_from_issues(audit_results)
        # Fallback score calculation if not provided
        total_issues = 0
        critical_issues = 0
        high_issues = 0
        
        if audit_results[:phases]
          audit_results[:phases].each do |phase|
            phase[:issues].each do |issue|
              total_issues += 1
              critical_issues += 1 if issue[:severity] == :critical
              high_issues += 1 if issue[:severity] == :high
            end
          end
        elsif audit_results[:summary]
          total_issues = audit_results[:summary][:total_issues] || 0
          critical_issues = audit_results[:summary][:critical] || 0
          high_issues = audit_results[:summary][:high] || 0
        end
        
        # Simple scoring algorithm
        if total_issues == 0
          100
        else
          base_score = 100
          deduction = (critical_issues * 15) + (high_issues * 8) + ((total_issues - critical_issues - high_issues) * 2)
          [base_score - deduction, 0].max
        end
      end

      def determine_badge_level(score)
        case score
        when 95..100 then :platinum
        when 85..94 then :gold
        when 75..84 then :silver
        when 65..74 then :bronze
        when 50..64 then :certified
        else :none
        end
      end

      def badge_color(level)
        {
          platinum: '#e5e4e2',
          gold: '#ffd700',
          silver: '#c0c0c0', 
          bronze: '#cd7f32',
          certified: '#4c9aff',
          none: '#ee4444'
        }[level]
      end

      def text_color(level)
        case level
        when :platinum, :silver
          '#333333'
        else
          '#ffffff'
        end
      end

      def extract_audit_summary(audit_results)
        if audit_results[:summary]
          audit_results[:summary]
        elsif audit_results[:phases]
          all_issues = audit_results[:phases].flat_map { |p| p[:issues] }
          {
            total_issues: all_issues.size,
            critical: all_issues.count { |i| i[:severity] == :critical },
            high: all_issues.count { |i| i[:severity] == :high },
            auto_fixable: all_issues.count { |i| i[:auto_fixable] }
          }
        else
          { total_issues: 0, critical: 0, high: 0, auto_fixable: 0 }
        end
      end

      def display_badge_info(badge_data)
        puts "\n🎯 Badge Information:".bold
        puts "  Level: #{badge_data[:level].to_s.capitalize} #{level_emoji(badge_data[:level])}"
        puts "  Score: #{badge_data[:score]}%"
        puts "  Color: #{badge_data[:color]}"
        puts ""
        
        puts "📊 Project Quality Summary:"
        summary = badge_data[:audit_summary]
        puts "  Total Issues: #{summary[:total_issues]}"
        puts "  Critical: #{summary[:critical]} 🚨" if summary[:critical] > 0
        puts "  High: #{summary[:high]} 🔴" if summary[:high] > 0
        puts "  Auto-fixable: #{summary[:auto_fixable]} ✅" if summary[:auto_fixable] > 0
        puts ""
        
        # Display badge preview based on format
        case @options[:format]
        when 'markdown'
          puts "📝 Markdown Badge:"
          puts generate_markdown_badge(badge_data).light_blue
        when 'html'
          puts "🌐 HTML Badge:"
          puts generate_html_badge(badge_data).light_blue
        when 'svg'
          puts "🖼️  SVG URL:"
          puts generate_svg_url(badge_data).light_blue
        else
          puts "📝 Markdown Badge:"
          puts generate_markdown_badge(badge_data).light_blue
          puts ""
          puts "🌐 HTML Badge:"
          puts generate_html_badge(badge_data).light_blue
        end
      end

      def save_badge_data(badge_data)
        output_dir = File.join(@project_path, 'tmp', 'smartrails_reports')
        FileUtils.mkdir_p(output_dir)
        
        badge_file = File.join(output_dir, 'smartrails_badge.json')
        File.write(badge_file, JSON.pretty_generate(badge_data))
        
        puts "💾 Badge data saved to: #{badge_file}".light_blue if @verbose
      end

      def update_readme(badge_data)
        readme_files = ['README.md', 'README.txt', 'readme.md', 'readme.txt']
        readme_file = readme_files.find { |f| File.exist?(File.join(@project_path, f)) }
        
        unless readme_file
          puts "⚠️  No README file found. Creating README.md with badge...".yellow
          create_readme_with_badge(badge_data)
          return
        end
        
        readme_path = File.join(@project_path, readme_file)
        content = File.read(readme_path)
        
        badge_markdown = generate_markdown_badge(badge_data)
        
        # Check if SmartRails badge already exists
        if content.include?('SmartRails')
          # Replace existing badge
          content.gsub!(/\[!\[SmartRails.*?\]\(.*?\)\]\(.*?\)/, badge_markdown)
          puts "🔄 Updated existing SmartRails badge in #{readme_file}".green
        else
          # Add badge at the top (after title if present)
          lines = content.split("\n")
          insert_index = find_badge_insertion_point(lines)
          
          lines.insert(insert_index, "", badge_markdown, "")
          content = lines.join("\n")
          puts "✅ Added SmartRails badge to #{readme_file}".green
        end
        
        File.write(readme_path, content)
      end

      def create_readme_with_badge(badge_data)
        project_name = File.basename(@project_path)
        badge_markdown = generate_markdown_badge(badge_data)
        
        readme_content = <<~MARKDOWN
          # #{project_name}
          
          #{badge_markdown}
          
          ## Description
          
          Add your project description here.
          
          ## SmartRails Quality Report
          
          This project maintains high code quality standards verified by SmartRails:
          - **Score**: #{badge_data[:score]}%
          - **Level**: #{badge_data[:level].to_s.capitalize} #{level_emoji(badge_data[:level])}
          - **Last Audit**: #{Time.now.strftime('%Y-%m-%d')}
          
          Run `smartrails audit` to generate a detailed quality report.
        MARKDOWN
        
        File.write(File.join(@project_path, 'README.md'), readme_content)
        puts "✅ Created README.md with SmartRails badge".green
      end

      def find_badge_insertion_point(lines)
        # Find where to insert the badge (after title, before content)
        title_index = lines.find_index { |line| line.start_with?('#') }
        
        if title_index
          # Insert after title and any existing badges
          insert_index = title_index + 1
          
          # Skip existing badges
          while insert_index < lines.size && 
                (lines[insert_index].empty? || 
                 lines[insert_index].start_with?('[![') ||
                 lines[insert_index].start_with?('!['))
            insert_index += 1
          end
          
          insert_index
        else
          # No title found, insert at the beginning
          0
        end
      end

      def generate_markdown_badge(badge_data)
        level_text = "#{badge_data[:level].to_s.capitalize}_#{badge_data[:score]}%25"
        color = badge_data[:color][1..-1] # Remove # from color
        
        shield_url = "https://img.shields.io/badge/SmartRails-#{level_text}-#{color}.svg"
        
        "[![SmartRails #{badge_data[:level].to_s.capitalize}](#{shield_url})](https://github.com/oasiisbox/SmartRails)"
      end

      def generate_html_badge(badge_data)
        level_text = "#{badge_data[:level].to_s.capitalize}_#{badge_data[:score]}%25"
        color = badge_data[:color][1..-1] # Remove # from color
        
        shield_url = "https://img.shields.io/badge/SmartRails-#{level_text}-#{color}.svg"
        
        "<a href='https://github.com/oasiisbox/SmartRails'><img src='#{shield_url}' alt='SmartRails #{badge_data[:level].to_s.capitalize}' /></a>"
      end

      def generate_svg_url(badge_data)
        level_text = "#{badge_data[:level].to_s.capitalize}_#{badge_data[:score]}%25"
        color = badge_data[:color][1..-1] # Remove # from color
        
        "https://img.shields.io/badge/SmartRails-#{level_text}-#{color}.svg"
      end

      def level_emoji(level)
        {
          platinum: '🏆',
          gold: '🥇',
          silver: '🥈',
          bronze: '🥉',
          certified: '✅',
          none: '❌'
        }[level]
      end
    end
  end
end