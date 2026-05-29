# frozen_string_literal: true

require 'io/console'
require 'optparse'

require_relative 'bundle'
require_relative 'clipboard'
require_relative 'obsidian'
require_relative 'picker'
require_relative 'settings'
require_relative 'sources'
require_relative 'tui'
require_relative 'version'

module Architext
  # rubocop:disable Metrics/ClassLength
  class CLI
    DEFAULT_QUERY = 'tag:#project/active'
    SOURCE_NATIVE = 'native'
    SOURCE_OBSIDIAN = 'obsidian'
    VAULT_SOURCE_EXPLICIT = '--vault'
    VAULT_SOURCE_SAVED_DEFAULT = 'saved default'
    VAULT_SOURCE_SESSION = 'session'
    VAULT_SOURCE_OBSIDIAN_DEFAULT = 'obsidian default'
    ROOT_SOURCE_EXPLICIT = '--root'
    ROOT_SOURCE_CWD = 'current folder'
    ROOT_SOURCE_SESSION = 'session'
    SearchAttempt = Data.define(:paths, :next_query)

    def initialize(argv, io: {}, app_name: 'architext', dependencies: {})
      @stdin = io.fetch(:stdin, $stdin)
      @stdout = io.fetch(:stdout, $stdout)
      @stderr = io.fetch(:stderr, $stderr)
      @clipboard = dependencies.fetch(:clipboard, Clipboard.new)
      @settings = dependencies.fetch(:settings, Settings.new)
      @argv = argv
      @app_name = app_name
      @options = {
        query: nil,
        source: SOURCE_NATIVE,
        root: Dir.pwd,
        vault: nil,
        set_default_vault: nil,
        clear_default_vault: false,
        diagnose: false,
        stdout: false,
        dry_run: false,
        all: false
      }
      @vault_source = VAULT_SOURCE_OBSIDIAN_DEFAULT
      @root_source = ROOT_SOURCE_CWD
    end

    def run
      parse_options
      return 0 if handled_default_vault_options?

      apply_default_vault
      normalize_source_options
      return run_diagnostics if @options[:diagnose]

      selected_paths = gather_selection
      return 1 unless selected_paths
      return no_selection if selected_paths.empty?

      source = build_source
      if @options[:dry_run]
        print_dry_run(selected_paths, source)
        return 0
      end

      files = read_selected_files(source, selected_paths)
      bundle = Bundle.new(files).to_markdown
      write_output(bundle)
      0
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
      ui.show_error "#{@app_name}: #{e.message}"
      @stderr.puts "Run `bin/#{@app_name} --help` for usage."
      2
    rescue Obsidian::CommandNotFound => e
      ui.show_error "#{@app_name}: #{e.message}"
      @stderr.puts 'Install/enable Obsidian CLI, or set ARCHITEXT_OBSIDIAN to its path.'
      127
    rescue Obsidian::CommandFailed, SourceError => e
      ui.show_error "#{@app_name}: #{e.message}"
      1
    rescue Interrupt
      @stderr.puts "\n#{@app_name}: cancelled"
      130
    end

    private

    # rubocop:disable Metrics/BlockLength
    def parse_options
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: bin/#{@app_name} [options]"

        opts.on('-q', '--query QUERY', "Markdown search query. Default: #{DEFAULT_QUERY}") do |value|
          @options[:query] = value
        end

        opts.on('--source SOURCE', 'Search source: native or obsidian. Default: native') do |value|
          source = value.to_s.strip.downcase
          raise OptionParser::InvalidArgument, '--source must be native or obsidian' unless valid_source?(source)

          @options[:source] = source
        end

        opts.on('--root PATH', 'Native markdown root. Default: current directory') do |value|
          @options[:root] = value
          @root_source = ROOT_SOURCE_EXPLICIT
        end

        opts.on('-v', '--vault VAULT', 'Obsidian vault name or id') do |value|
          @options[:vault] = value
          @options[:source] = SOURCE_OBSIDIAN
        end

        opts.on('--set-default-vault VAULT', 'Set persistent default vault for future runs') do |value|
          @options[:set_default_vault] = value
        end

        opts.on('--clear-default-vault', 'Clear persistent default vault') do
          @options[:clear_default_vault] = true
        end

        opts.on('--diagnose', 'Print source diagnostics, then exit') do
          @options[:diagnose] = true
        end

        opts.on('--stdout', 'Print stitched context instead of copying to clipboard') do
          @options[:stdout] = true
        end

        opts.on('--dry-run', 'Show selected files and estimated bundle size') do
          @options[:dry_run] = true
        end

        opts.on('--all', 'Include all search results without opening the picker') do
          @options[:all] = true
        end

        opts.on('-h', '--help', 'Show this help') do
          @stdout.puts opts
          exit 0
        end

        opts.on('--version', 'Show version') do
          @stdout.puts Architext::VERSION
          exit 0
        end
      end

      parser.parse!(@argv)
    end
    # rubocop:enable Metrics/BlockLength

    def valid_source?(source)
      [SOURCE_NATIVE, SOURCE_OBSIDIAN].include?(source)
    end

    def gather_selection
      query = @options[:query] || prompt_for_query
      return nil if query.nil?

      loop do
        source = build_source
        attempt = search_with_recovery(source, query)
        if attempt.next_query
          query = attempt.next_query
          return nil if query.nil?

          next
        end

        paths = attempt.paths
        if paths.empty?
          query = handle_no_results(query, source.diagnostics)
          return nil if query.nil?

          next
        end

        selection = select_paths(paths, query:, diagnostics: source.diagnostics)
        if selection.source_config
          handle_prompt_source_config
          next
        end

        if selection.reprompt_query
          query = prompt_for_query

          return nil if query.nil?

          next
        end

        return selection.paths unless selection.new_query

        query = selection.new_query
      end
    end

    def search_with_recovery(client, query)
      SearchAttempt.new(paths: client.search(query), next_query: nil)
    rescue Obsidian::CommandFailed => e
      if query_uses_operators?(query) && silent_exit_127?(e.message)
        ui.show_info('Search operator query failed on this Obsidian CLI session. Retrying with plain-text fallback...')
        fallback = operator_free_query(query)
        retried = search_plain_fallback(client, fallback)
        return retried if retried
      end

      next_query = handle_search_error(query, e)
      return SearchAttempt.new(paths: [], next_query:) if interactive?

      raise e
    end

    def handled_default_vault_options?
      if @options[:set_default_vault]
        vault = @options[:set_default_vault].to_s.strip
        raise Obsidian::CommandFailed, 'default vault cannot be blank' if vault.empty?

        @settings.default_vault = vault
        @stdout.puts "Default vault set to: #{vault}"
        return true
      end

      return false unless @options[:clear_default_vault]

      @settings.clear_default_vault
      @stdout.puts 'Default vault cleared.'
      true
    end

    def apply_default_vault
      return unless @options[:source] == SOURCE_OBSIDIAN

      if @options[:vault]
        @vault_source = VAULT_SOURCE_EXPLICIT
        return
      end

      default_vault = @settings.default_vault
      @options[:vault] = default_vault
      @vault_source = default_vault ? VAULT_SOURCE_SAVED_DEFAULT : VAULT_SOURCE_OBSIDIAN_DEFAULT
    end

    def normalize_source_options
      @options[:root] = File.expand_path(@options[:root].to_s)
      return unless @options[:source] == SOURCE_NATIVE

      @options[:vault] = nil
      @vault_source = VAULT_SOURCE_OBSIDIAN_DEFAULT
    end

    def prompt_for_query
      return DEFAULT_QUERY unless interactive?

      loop do
        connection = build_connection_report
        input = ui.prompt_query(
          default: DEFAULT_QUERY,
          context: {
            source: @options[:source],
            root: @options[:root],
            root_source: @root_source,
            vault: @options[:vault],
            vault_source: @vault_source,
            default_vault: @settings.default_vault,
            default_vault_path: @settings.config_path,
            connection_report: connection
          }
        )
        return nil if input.quit

        if input.open_vault_config
          handle_prompt_source_config
          next
        end

        return input.query
      end
    end

    def build_connection_report
      diagnostics = build_source.diagnostics
      warning = diagnostics.warning
      warning ||= vault_mismatch_warning(diagnostics.resolved_vault_summary, @options[:vault]) if diagnostics.source == SOURCE_OBSIDIAN
      diagnostics.to_h.merge(warning:)
    rescue SourceError => e
      SourceDiagnostics.new(
        source: @options[:source],
        root: @options[:root],
        vault: @options[:vault],
        vault_source: @vault_source,
        status: 'error',
        warning: e.message,
        markdown_count: nil,
        executable: nil,
        version: nil,
        resolved_vault_summary: nil
      ).to_h
    end

    def run_diagnostics
      report = build_connection_report
      @stdout.puts "ARCHiTEXT diagnostics (v#{Architext::VERSION})"
      @stdout.puts "active source: #{report[:source]}"
      report[:source] == SOURCE_OBSIDIAN ? print_obsidian_diagnostics(report) : print_native_diagnostics(report)
      @stdout.puts "connection check: #{report[:status]}"
      @stdout.puts "diagnostic warning: #{report[:warning]}" if report[:warning]
      report[:status] == 'ok' ? 0 : 1
    end

    def print_native_diagnostics(report)
      @stdout.puts "root path: #{report[:root]}"
      @stdout.puts "markdown files: #{report[:markdown_count] || 'unknown'}"
    end

    def print_obsidian_diagnostics(report)
      @stdout.puts "active vault ref: #{@options[:vault] || '(none selected)'}"
      @stdout.puts "vault source: #{@vault_source}"
      @stdout.puts "saved default vault: #{@settings.default_vault || '(none)'}"
      @stdout.puts "default vault config path: #{@settings.config_path}"
      @stdout.puts "obsidian cli executable: #{report[:executable]}"
      @stdout.puts "obsidian cli version: #{report[:version] || 'unknown'}"
      @stdout.puts "resolved vault: #{report[:resolved_vault_summary] || '(unknown)'}"
    end

    def handle_no_results(query, diagnostics)
      ui.show_no_results(
        query,
        diagnostics: diagnostics.to_h,
        default_vault_path: @settings.config_path,
        obsidian_executable: ENV.fetch('ARCHITEXT_OBSIDIAN', 'obsidian')
      )
      interactive? ? prompt_for_query : nil
    end

    def handle_search_error(_query, error)
      if interactive?
        ui.show_error("#{error.message}\nReturning to search prompt.")
        return prompt_for_query
      end

      raise error
    end

    def select_paths(paths, query:, diagnostics:)
      return TUI::Selection.new(paths:, new_query: nil, source_config: false, reprompt_query: false) if @options[:all]

      raise SourceError, 'interactive selection requires a TTY; rerun with --all or provide input from a terminal' unless interactive?

      ui.select(paths, query:, diagnostics: diagnostics.to_h)
    end

    def handle_prompt_source_config
      loop do
        context = {
          source: @options[:source],
          root: @options[:root],
          root_source: @root_source,
          active_vault: @options[:vault],
          active_vault_source: @vault_source,
          default_vault: @settings.default_vault,
          default_vault_path: @settings.config_path
        }
        action = ui.prompt_source_config(context)
        return if action.back

        apply_source_config_action(action)
      end
    end

    def build_source
      return ObsidianSource.new(vault: @options[:vault], vault_source: @vault_source) if @options[:source] == SOURCE_OBSIDIAN

      NativeMarkdownSource.new(root: @options[:root])
    end

    def apply_source_config_action(action)
      if action.clear_default
        @settings.clear_default_vault
        ui.show_info('Default vault cleared.')
      elsif action.set_default_vault
        @settings.default_vault = action.set_default_vault
        ui.show_info("Default vault set to: #{action.set_default_vault}")
      elsif action.session_root
        apply_native_root(action.session_root)
      elsif action.session_vault
        apply_obsidian_vault(action.session_vault)
      end
    end

    def apply_native_root(root)
      @options[:source] = SOURCE_NATIVE
      @options[:root] = File.expand_path(root.strip)
      @root_source = ROOT_SOURCE_SESSION
      @options[:vault] = nil
      @vault_source = VAULT_SOURCE_OBSIDIAN_DEFAULT
    end

    def apply_obsidian_vault(vault_value)
      @options[:source] = SOURCE_OBSIDIAN
      vault = vault_value.strip
      vault = nil if vault.empty?
      @options[:vault] = vault
      @vault_source = vault.nil? ? VAULT_SOURCE_OBSIDIAN_DEFAULT : VAULT_SOURCE_SESSION
    end

    def print_dry_run(selected_paths, client)
      files = read_selected_files(client, selected_paths)
      bytes = Bundle.new(files).to_markdown.bytesize
      ui.show_dry_run(selected_paths, bytes)
    end

    def read_selected_files(client, selected_paths)
      selected_paths.map do |path|
        FileContent.new(path:, content: client.read(path))
      end
    end

    def write_output(bundle)
      if @options[:stdout]
        @stdout.write bundle
        return
      end

      @clipboard.copy(bundle)
      ui.show_copied(bundle.bytesize)
    rescue Clipboard::Error => e
      raise SourceError, "#{e.message}\nTip: rerun with --stdout to print the bundle."
    end

    def query_uses_operators?(query)
      query.to_s.match?(/(^|\s)(tag|path|file|line):/i)
    end

    def silent_exit_127?(message)
      message.to_s.match?(/exit\s+127/i)
    end

    def operator_free_query(query)
      query.to_s.gsub(/(^|\s)[a-z]+:[^\s]+/i, ' ').gsub('#', ' ').strip
    end

    def search_plain_fallback(client, query)
      return nil if query.empty?

      SearchAttempt.new(paths: client.search(query), next_query: nil)
    rescue Obsidian::CommandFailed
      nil
    end

    def vault_mismatch_warning(vault_summary, requested_vault)
      return nil if requested_vault.to_s.strip.empty?
      return nil if vault_summary.to_s.downcase.include?(requested_vault.to_s.downcase)

      "Requested vault '#{requested_vault}' may not match resolved vault reported by Obsidian CLI."
    end

    def no_selection
      ui.show_no_selection
      1
    end

    def interactive?
      @stdin.tty? && @stdout.tty?
    end

    def ui
      @ui ||= TUI.new(stdin: @stdin, stdout: @stdout, stderr: @stderr, app_name: @app_name)
    end
  end
  # rubocop:enable Metrics/ClassLength
end
