# frozen_string_literal: true

module SpecHelpers
  module FileSystemHelper
    def create_temp_file(content, extension = '.rb')
      file = Tempfile.new(['test', extension])
      file.write(content)
      file.close
      file.path
    end

    def create_temp_directory
      Dir.mktmpdir
    end

    def with_temp_directory
      dir = create_temp_directory
      yield(dir)
    ensure
      FileUtils.rm_rf(dir) if dir && Dir.exist?(dir)
    end

    def write_file(path, content)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end

    def read_file(path)
      File.read(path) if File.exist?(path)
    end
  end
end