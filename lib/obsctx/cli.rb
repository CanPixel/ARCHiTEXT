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
  class CLI
    DEFAULT_QUERY = 'tag:#project/active'

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
        stdout: false,
        dry_run: false,
        all: false
      }
    end

    def run
      parse_options
      return 0 if handled_default_vault_options?

      apply_default_vault
      selected_paths = gather_selection
      return 1 unless selected_paths
      return no_selection if selected_paths.empty?

      if @options[:dry_run]
        print_dry_run(selected_paths, client)
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

    def gather_selection
      query = @options[:query] || prompt_for_query
      vault = @options[:vault]

      loop do
        client = Obsidian.new(vault:)
        paths = client.search(query)
        return no_results_for_selection(query, vault) if paths.empty?

        selection = select_paths(paths, query:, vault:)
        if selection.new_vault
          vault = selection.new_vault.strip
          vault = nil if vault.empty?
          @options[:vault] = vault
          next
        end

        if selection.reprompt_query
          query = prompt_for_query
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
      return if @options[:vault]

      @options[:vault] = @settings.default_vault
    end

    def prompt_for_query
      return DEFAULT_QUERY unless interactive?

      ui.prompt_query(default: DEFAULT_QUERY)
    end

    def select_paths(paths, query:, vault:)
      return TUI::Selection.new(paths:, new_query: nil, new_vault: nil, reprompt_query: false) if @options[:all]

      unless interactive?
        raise Obsidian::CommandFailed,
              'interactive selection requires a TTY; rerun with --all or provide input from a terminal'
      end

      ui.select(paths, query:, vault:)
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

    def no_results_for_selection(query, vault)
      ui.show_no_results(query, vault:)
      nil
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
end
