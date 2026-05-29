# frozen_string_literal: true

require 'find'
require 'pathname'

require_relative 'obsidian'

module Architext
  SourceDiagnostics = Data.define(
    :source,
    :root,
    :vault,
    :vault_source,
    :status,
    :warning,
    :markdown_count,
    :executable,
    :version,
    :resolved_vault_summary
  )

  class SourceError < StandardError; end
  class SourceNotFound < SourceError; end

  class NativeMarkdownSource
    MARKDOWN_EXTENSIONS = %w[.md .markdown].freeze
    EXCLUDED_DIRECTORIES = %w[.git .bundle node_modules vendor].freeze

    SearchToken = Data.define(:kind, :value)
    SearchResult = Data.define(:path, :score)

    attr_reader :root

    def initialize(root: Dir.pwd)
      @root = File.realpath(File.expand_path(root.to_s))
    rescue Errno::ENOENT, Errno::ENOTDIR
      raise SourceNotFound, "Markdown root not found: #{root}"
    end

    def search(query)
      tokens = parse_query(query)
      results = markdown_files.filter_map do |path|
        relative = relative_path(path)
        content = read_absolute(path)
        next unless tokens.empty? || tokens.all? { |token| token_matches?(token, relative, content) }

        SearchResult.new(path: relative, score: relevance_score(tokens, relative, content))
      end

      results.uniq(&:path)
             .sort_by { |result| [-result.score, result.path.downcase] }
             .map(&:path)
    end

    def read(path)
      absolute = resolve_relative(path)
      raise SourceNotFound, "Markdown file not found: #{path}" unless File.file?(absolute)
      raise SourceError, "Not a markdown file: #{path}" unless markdown_file?(absolute)

      read_absolute(absolute)
    end

    def diagnostics
      SourceDiagnostics.new(
        source: 'native',
        root: @root,
        vault: nil,
        vault_source: nil,
        status: 'ok',
        warning: nil,
        markdown_count: markdown_files.length,
        executable: nil,
        version: nil,
        resolved_vault_summary: nil
      )
    rescue SourceError => e
      SourceDiagnostics.new(
        source: 'native',
        root: @root,
        vault: nil,
        vault_source: nil,
        status: 'error',
        warning: e.message,
        markdown_count: nil,
        executable: nil,
        version: nil,
        resolved_vault_summary: nil
      )
    end

    private

    def markdown_files
      files = []
      Find.find(@root) do |path|
        if File.directory?(path)
          Find.prune if excluded_directory?(path)
          next
        end

        files << path if markdown_file?(path)
      end
      files.sort_by { |path| relative_path(path).downcase }
    end

    def excluded_directory?(path)
      return false if path == @root

      basename = File.basename(path)
      basename.start_with?('.') || EXCLUDED_DIRECTORIES.include?(basename)
    end

    def markdown_file?(path)
      MARKDOWN_EXTENSIONS.include?(File.extname(path).downcase)
    end

    def parse_query(query)
      query.to_s.scan(/"([^"]+)"|(\S+)/).filter_map do |quoted, bare|
        raw = (quoted || bare).to_s.strip
        next if raw.empty?

        case raw
        when /\Atag:(.+)\z/i
          SearchToken.new(kind: :tag, value: Regexp.last_match(1).sub(/\A#/, '').downcase)
        when /\A(?:path|file):(.+)\z/i
          SearchToken.new(kind: :path, value: Regexp.last_match(1).downcase)
        else
          SearchToken.new(kind: :text, value: raw.downcase)
        end
      end
    end

    def token_matches?(token, relative, content)
      path = relative.downcase
      text = content.downcase

      case token.kind
      when :path
        path.include?(token.value)
      when :tag
        tag_matches?(token.value, content)
      else
        path.include?(token.value) || text.include?(token.value)
      end
    end

    def tag_matches?(tag, content)
      return false if tag.empty?

      escaped = Regexp.escape(tag)
      pattern = if tag.include?('/')
                  %r{(?<![\w/-])##{escaped}(?![\w/-])}i
                else
                  %r{(?<![\w/-])##{escaped}(?:/[\w-]+)*(?![\w/-])}i
                end
      content.match?(pattern)
    end

    def relevance_score(tokens, relative, content)
      return 0 if tokens.empty?

      path = relative.downcase
      text = content.downcase
      tokens.sum do |token|
        case token.kind
        when :path
          path.include?(token.value) ? 30 : 0
        when :tag
          tag_matches?(token.value, content) ? 40 : 0
        else
          (path.include?(token.value) ? 20 : 0) + text.scan(Regexp.escape(token.value)).length
        end
      end
    end

    def resolve_relative(path)
      requested = Pathname.new(File.expand_path(path.to_s, @root)).cleanpath
      root_path = Pathname.new(@root)
      relative = requested.relative_path_from(root_path).to_s
      raise SourceError, "Path escapes markdown root: #{path}" if relative.start_with?('..')

      requested.to_s
    rescue ArgumentError
      raise SourceError, "Path escapes markdown root: #{path}"
    end

    def relative_path(path)
      Pathname.new(path).relative_path_from(Pathname.new(@root)).to_s
    end

    def read_absolute(path)
      text = File.binread(path).to_s
      text.force_encoding(Encoding::UTF_8)
      text.valid_encoding? ? text : text.scrub
    rescue Errno::EACCES
      raise SourceError, "Cannot read markdown file: #{relative_path(path)}"
    end
  end

  class ObsidianSource
    attr_reader :vault, :vault_source

    def initialize(vault: nil, vault_source: nil, executable: ENV.fetch('ARCHITEXT_OBSIDIAN', 'obsidian'))
      @vault = vault
      @vault_source = vault_source
      @executable = executable
      @client = Obsidian.new(vault:, executable:)
    end

    def search(query)
      @client.search(query)
    end

    def read(path)
      @client.read(path)
    end

    def diagnostics
      version = @client.version
      vault_info = @client.vault_info
      SourceDiagnostics.new(
        source: 'obsidian',
        root: nil,
        vault: @vault,
        vault_source: @vault_source,
        status: 'ok',
        warning: nil,
        markdown_count: nil,
        executable: @executable,
        version:,
        resolved_vault_summary: summarize_vault_info(vault_info)
      )
    rescue Obsidian::CommandFailed => e
      SourceDiagnostics.new(
        source: 'obsidian',
        root: nil,
        vault: @vault,
        vault_source: @vault_source,
        status: 'error',
        warning: first_line(e.message),
        markdown_count: nil,
        executable: @executable,
        version: nil,
        resolved_vault_summary: nil
      )
    end

    private

    def summarize_vault_info(text)
      lines = text.to_s.lines.map(&:strip).reject(&:empty?)
      kv = lines.each_with_object({}) do |line, memo|
        next unless line.match?(/\A[a-zA-Z0-9_]+\s+/)

        key, value = line.split(/\s+/, 2)
        memo[key.downcase] = value
      end

      name = kv['name']
      path = kv['path']
      return "#{name} | #{path}" if name && path
      return name if name
      return path if path

      lines.join(' | ')[0, 180]
    end

    def first_line(text)
      text.to_s.lines.first.to_s.strip
    end
  end
end
