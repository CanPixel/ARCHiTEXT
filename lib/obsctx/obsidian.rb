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
      json_output = run('search', "query=#{query}", 'format=json')
      json_paths = SearchResults.parse(json_output)
      return json_paths unless json_paths.empty?

      text_output = run('search', "query=#{query}", 'format=text')
      SearchResults.parse(text_output)
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
      stdout = normalize_output(stdout)
      stderr = normalize_output(stderr)
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

    def normalize_output(output)
      text = output.to_s.dup
      text.force_encoding(Encoding::UTF_8)
      text.valid_encoding? ? text : text.scrub
    end
  end
end
