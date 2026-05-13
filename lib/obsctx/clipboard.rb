# frozen_string_literal: true

require 'open3'
require 'rbconfig'

module ObsidianContext
  class Clipboard
    class Error < StandardError; end
    class UnsupportedPlatform < Error; end
    class CommandFailed < Error; end

    def initialize(runner: Open3.method(:capture3), env: ENV, host_os: RbConfig::CONFIG['host_os'])
      @runner = runner
      @env = env
      @host_os = host_os.to_s.downcase
    end

    def copy(text)
      command = resolve_command
      _out, err, status = @runner.call(*command, stdin_data: text.to_s)
      return if status.success?

      details = err.to_s.strip
      details = "exit #{status.exitstatus}" if details.empty?
      raise CommandFailed, "Clipboard command failed: #{command.join(' ')} (#{details})"
    rescue Errno::ENOENT
      raise UnsupportedPlatform, "Clipboard command not found: #{command.join(' ')}"
    end

    private

    def resolve_command
      candidates.each do |command|
        return command if command_available?(command.first)
      end

      raise UnsupportedPlatform,
            'No supported clipboard command found. Use --stdout to print and pipe to your clipboard tool.'
    end

    def candidates
      return [%w[pbcopy]] if mac?
      return [%w[clip], %w[powershell -NoProfile -Command Set-Clipboard]] if windows?

      [%w[wl-copy], %w[xclip -selection clipboard], %w[xsel --clipboard --input]]
    end

    def command_available?(executable)
      return false if executable.to_s.empty?

      path = @env.fetch('PATH', '')
      exts = executable_extensions

      path.split(File::PATH_SEPARATOR).any? do |dir|
        exts.any? do |ext|
          candidate = File.join(dir, "#{executable}#{ext}")
          File.file?(candidate) && File.executable?(candidate)
        end
      end
    end

    def executable_extensions
      return [''] unless windows?

      pathext = @env.fetch('PATHEXT', '.EXE;.BAT;.CMD')
      pathext.split(';').map(&:downcase).unshift('')
    end

    def mac?
      @host_os.include?('darwin')
    end

    def windows?
      @host_os.match?(/mswin|mingw|cygwin/)
    end
  end
end
