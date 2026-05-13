# frozen_string_literal: true

require 'io/console'
require 'optparse'
require 'shellwords'

require_relative 'bundle'
require_relative 'clipboard'
require_relative 'obsidian'
require_relative 'picker'
require_relative 'settings'
require_relative 'tui'
require_relative 'version'

module ObsidianContext
  # rubocop:disable Metrics/ClassLength
  class CLI
    DEFAULT_QUERY = 'tag:#project/active'
    VAULT_SOURCE_EXPLICIT = '--vault'
    VAULT_SOURCE_SAVED_DEFAULT = 'saved default'
    VAULT_SOURCE_SESSION = 'session'
    VAULT_SOURCE_OBSIDIAN_DEFAULT = 'obsidian default'

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
        vault: nil,
        set_default_vault: nil,
        clear_default_vault: false,
        diagnose: false,
        stdout: false,
        dry_run: false,
        all: false
      }
      @vault_source = VAULT_SOURCE_OBSIDIAN_DEFAULT
    end

    def run
      parse_options
      return 0 if handled_default_vault_options?

      apply_default_vault
      return run_diagnostics if @options[:diagnose]

      selected_paths = gather_selection
      return 1 unless selected_paths
      return no_selection if selected_paths.empty?

      if @options[:dry_run]
        print_dry_run(selected_paths, Obsidian.new(vault: @options[:vault]))
        return 0
      end

      files = read_selected_files(Obsidian.new(vault: @options[:vault]), selected_paths)
      bundle = Bundle.new(files).to_markdown
      write_output(bundle)
      0
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
      ui.show_error "#{@app_name}: #{e.message}"
      @stderr.puts "Run `bin/#{@app_name} --help` for usage."
      2
    rescue Obsidian::CommandNotFound => e
      ui.show_error "#{@app_name}: #{e.message}"
      @stderr.puts 'Install/enable Obsidian CLI, or set OBSCTX_OBSIDIAN to its path.'
      127
    rescue Obsidian::CommandFailed => e
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

        opts.on('-q', '--query QUERY', "Obsidian search query. Default: #{DEFAULT_QUERY}") do |value|
          @options[:query] = value
        end

        opts.on('-v', '--vault VAULT', 'Obsidian vault name or id') do |value|
          @options[:vault] = value
        end

        opts.on('--set-default-vault VAULT', 'Set persistent default vault for future runs') do |value|
          @options[:set_default_vault] = value
        end

        opts.on('--clear-default-vault', 'Clear persistent default vault') do
          @options[:clear_default_vault] = true
        end

        opts.on('--diagnose', 'Print Obsidian CLI and vault diagnostics, then exit') do
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
          @stdout.puts ObsidianContext::VERSION
          exit 0
        end
      end

      parser.parse!(@argv)
    end
    # rubocop:enable Metrics/BlockLength

    def gather_selection
      query = @options[:query] || prompt_for_query
      return nil if query.nil?

      vault = @options[:vault]
      vault_source = @vault_source

      loop do
        client = Obsidian.new(vault:)
        paths = client.search(query)
        return no_results_for_selection(query, vault, vault_source) if paths.empty?

        selection = select_paths(paths, query:, vault:, vault_source:)
        if selection.new_vault
          vault = selection.new_vault.strip
          vault = nil if vault.empty?
          @options[:vault] = vault
          vault_source = vault.nil? ? VAULT_SOURCE_OBSIDIAN_DEFAULT : VAULT_SOURCE_SESSION
          @vault_source = vault_source
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
      if @options[:vault]
        @vault_source = VAULT_SOURCE_EXPLICIT
        return
      end

      default_vault = @settings.default_vault
      @options[:vault] = default_vault
      @vault_source = default_vault ? VAULT_SOURCE_SAVED_DEFAULT : VAULT_SOURCE_OBSIDIAN_DEFAULT
    end

    def prompt_for_query
      return DEFAULT_QUERY unless interactive?

      loop do
        connection = build_connection_report
        input = ui.prompt_query(
          default: DEFAULT_QUERY,
          context: {
            vault: @options[:vault],
            vault_source: @vault_source,
            default_vault: @settings.default_vault,
            default_vault_path: @settings.config_path,
            connection_report: connection
          }
        )
        return nil if input.quit

        if input.open_vault_config
          handle_prompt_vault_config
          next
        end

        return input.query
      end
    end

    def build_connection_report
      report = {
        executable: ENV.fetch('OBSCTX_OBSIDIAN', 'obsidian'),
        status: 'unknown',
        version: nil,
        resolved_vault_summary: nil,
        warning: nil
      }
      client = Obsidian.new(vault: @options[:vault], executable: report[:executable])
      report[:version] = client.version
      report[:resolved_vault_summary] = summarize_vault_info(client.vault_info)
      report[:status] = 'ok'
      report[:warning] = vault_mismatch_warning(report[:resolved_vault_summary], @options[:vault])
      report
    rescue Obsidian::CommandFailed => e
      report[:status] = 'error'
      report[:warning] = first_line(e.message)
      report
    rescue Obsidian::CommandNotFound => e
      report[:status] = 'error'
      report[:warning] = e.message
      report
    end

    def run_diagnostics
      report = build_connection_report
      @stdout.puts "ARCHiTEXT diagnostics (v#{ObsidianContext::VERSION})"
      @stdout.puts "active vault ref: #{@options[:vault] || '(none selected)'}"
      @stdout.puts "vault source: #{@vault_source}"
      @stdout.puts "saved default vault: #{@settings.default_vault || '(none)'}"
      @stdout.puts "default vault config path: #{@settings.config_path}"
      @stdout.puts "obsidian cli executable: #{report[:executable]}"
      @stdout.puts "obsidian cli version: #{report[:version] || 'unknown'}"
      @stdout.puts "connection check: #{report[:status]}"
      @stdout.puts "resolved vault: #{report[:resolved_vault_summary] || '(unknown)'}"
      @stdout.puts "diagnostic warning: #{report[:warning]}" if report[:warning]
      report[:status] == 'ok' ? 0 : 1
    end

    def select_paths(paths, query:, vault:, vault_source:)
      return TUI::Selection.new(paths:, new_query: nil, new_vault: nil, reprompt_query: false) if @options[:all]

      unless interactive?
        raise Obsidian::CommandFailed,
              'interactive selection requires a TTY; rerun with --all or provide input from a terminal'
      end

      ui.select(paths, query:, vault:, vault_source:)
    end

    def handle_prompt_vault_config
      loop do
        action = ui.prompt_vault_config(
          active_vault: @options[:vault],
          active_vault_source: @vault_source,
          default_vault: @settings.default_vault,
          default_vault_path: @settings.config_path
        )
        return if action.back

        if action.clear_default
          @settings.clear_default_vault
          ui.show_info('Default vault cleared.')
          next
        end

        if action.set_default_vault
          @settings.default_vault = action.set_default_vault
          ui.show_info("Default vault set to: #{action.set_default_vault}")
          next
        end

        next unless action.session_vault

        vault = action.session_vault.strip
        vault = nil if vault.empty?
        @options[:vault] = vault
        @vault_source = vault.nil? ? VAULT_SOURCE_OBSIDIAN_DEFAULT : VAULT_SOURCE_SESSION
      end
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
      raise Obsidian::CommandFailed, "#{e.message}\nTip: rerun with --stdout to print the bundle."
    end

    def no_results_for_selection(query, vault, vault_source)
      ui.show_no_results(
        query,
        vault:,
        vault_source:,
        default_vault_path: @settings.config_path,
        obsidian_executable: ENV.fetch('OBSCTX_OBSIDIAN', 'obsidian')
      )
      nil
    end

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

      compact = lines.join(' | ')
      compact[0, 180]
    end

    def vault_mismatch_warning(vault_summary, requested_vault)
      return nil if requested_vault.to_s.strip.empty?
      return nil if vault_summary.to_s.downcase.include?(requested_vault.to_s.downcase)

      "Requested vault '#{requested_vault}' may not match resolved vault reported by Obsidian CLI."
    end

    def first_line(text)
      text.to_s.lines.first.to_s.strip
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
