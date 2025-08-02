# frozen_string_literal: true

RSpec.describe SmartRails::Auditors::BaseAuditor do
  let(:project_root) { create_temp_rails_project }
  let(:auditor) { described_class.new(project_root) }

  describe '#initialize' do
    it 'sets the project root' do
      expect(auditor.project_root).to eq(project_root)
    end

    it 'initializes empty issues array' do
      expect(auditor.issues).to be_empty
    end
  end

  describe '#run' do
    it 'raises NotImplementedError for base class' do
      expect { auditor.run }.to raise_error(NotImplementedError)
    end
  end

  describe '#add_issue' do
    it 'adds an issue to the issues array' do
      auditor.send(:add_issue,
        type: 'Test Issue',
        message: 'This is a test issue',
        severity: :medium,
        file: 'test_file.rb'
      )

      expect(auditor.issues).to have(1).item
      
      issue = auditor.issues.first
      expect(issue[:type]).to eq('Test Issue')
      expect(issue[:message]).to eq('This is a test issue')
      expect(issue[:severity]).to eq(:medium)
      expect(issue[:file]).to eq('test_file.rb')
    end

    it 'sets default severity to medium if not provided' do
      auditor.send(:add_issue,
        type: 'Test Issue',
        message: 'This is a test issue',
        file: 'test_file.rb'
      )

      issue = auditor.issues.first
      expect(issue[:severity]).to eq(:medium)
    end

    it 'marks issue as auto_fixable when auto_fix is provided' do
      fix_proc = -> { puts 'fixing' }
      
      auditor.send(:add_issue,
        type: 'Test Issue',
        message: 'This is a test issue',
        file: 'test_file.rb',
        auto_fix: fix_proc
      )

      issue = auditor.issues.first
      expect(issue[:auto_fixable]).to be true
      expect(issue[:auto_fix]).to eq(fix_proc)
    end
  end

  describe '#rails_project?' do
    it 'returns true for a valid Rails project' do
      expect(auditor.send(:rails_project?)).to be true
    end

    it 'returns false when Gemfile is missing' do
      File.delete(File.join(project_root, 'Gemfile'))
      expect(auditor.send(:rails_project?)).to be false
    end

    it 'returns false when config/application.rb is missing' do
      File.delete(File.join(project_root, 'config', 'application.rb'))
      expect(auditor.send(:rails_project?)).to be false
    end
  end

  describe '#find_files' do
    it 'finds Ruby files matching a pattern' do
      create_rails_controller(project_root, 'users')
      create_rails_controller(project_root, 'posts')

      files = auditor.send(:find_files, 'app/controllers/**/*_controller.rb')
      
      expect(files).to include(end_with('users_controller.rb'))
      expect(files).to include(end_with('posts_controller.rb'))
    end

    it 'returns empty array when no files match' do
      files = auditor.send(:find_files, 'nonexistent/**/*.rb')
      expect(files).to be_empty
    end
  end

  describe '#read_file_safely' do
    it 'reads file content when file exists' do
      test_file = File.join(project_root, 'test.rb')
      File.write(test_file, 'puts "hello"')

      content = auditor.send(:read_file_safely, test_file)
      expect(content).to eq('puts "hello"')
    end

    it 'returns empty string when file does not exist' do
      content = auditor.send(:read_file_safely, 'nonexistent.rb')
      expect(content).to eq('')
    end

    it 'returns empty string when file cannot be read' do
      test_file = File.join(project_root, 'unreadable.rb')
      File.write(test_file, 'content')
      File.chmod(0000, test_file)

      content = auditor.send(:read_file_safely, test_file)
      expect(content).to eq('')
      
      # Clean up
      File.chmod(0644, test_file)
      File.delete(test_file)
    end
  end
end