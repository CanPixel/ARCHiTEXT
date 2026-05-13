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
      copied = false

      candidates.each do |command|
        _out, err, status = @runner.call(*command, stdin_data: text.to_s)
        if status.success?
          copied = true
          break
        end

        details = err.to_s.strip
        details = "exit #{status.exitstatus}" if details.empty?
        raise CommandFailed, "Clipboard command failed: #{command.join(' ')} (#{details})"
      rescue Errno::ENOENT
        next
      end

      return if copied

      raise UnsupportedPlatform,
            'No supported clipboard command found. Use --stdout to print and pipe to your clipboard tool.'
    end

    private

    def candidates
      return [%w[pbcopy]] if mac?
      return [%w[clip], %w[powershell -NoProfile -Command Set-Clipboard]] if windows?

      [%w[wl-copy], %w[xclip -selection clipboard], %w[xsel --clipboard --input]]
    end

    def mac?
      @host_os.include?('darwin')
    end

    def windows?
      @host_os.match?(/mswin|mingw|cygwin/)
    end
  end
end
