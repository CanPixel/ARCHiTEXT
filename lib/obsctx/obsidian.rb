# frozen_string_literal: true

require 'open3'
require 'shellwords'

require_relative 'search_results'

module ObsidianContext
  class Obsidian
    class CommandFailed < StandardError; end
    class CommandNotFound < CommandFailed; end

    def initialize(vault: nil, executable: ENV.fetch('OBSCTX_OBSIDIAN', 'obsidian'))
      @vault = vault
      @executable = executable
    end

    def search(query)
      stdout = run('search', "query=#{query}", 'format=json')
      SearchResults.parse(stdout)
    end

    def read(path)
      run('read', "path=#{path}")
    end

    def version
      run('version').to_s.strip
    end

    def vault_info
      run('vault').to_s
    end

    private

    def run(*args)
      command = [@executable]
      command << "vault=#{@vault}" if @vault && !@vault.empty?
      command.concat(args)

      stdout, stderr, status = Open3.capture3(*command)
      return stdout if status.success?

      if status.exitstatus == 127 || stderr.match?(/not found|no such file/i)
        raise CommandNotFound, "Obsidian CLI executable not found: #{@executable}"
      end

      rendered = command.shelljoin
      details = stderr.strip.empty? ? "exit #{status.exitstatus}" : stderr.strip
      raise CommandFailed, "Obsidian command failed: #{rendered}\n#{details}"
    rescue Errno::ENOENT
      raise CommandNotFound, "Obsidian CLI executable not found: #{@executable}"
    end
  end
end
