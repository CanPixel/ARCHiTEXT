# frozen_string_literal: true

require "io/console"
require "open3"
require "optparse"
require "shellwords"

require_relative "bundle"
require_relative "obsidian"
require_relative "picker"
require_relative "tui"

module ObsidianContext
  class CLI
    DEFAULT_QUERY = "tag:#project/active"

    def initialize(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr, app_name: "architext")
      @argv = argv
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
      @app_name = app_name
      @options = {
        query: nil,
        vault: nil,
        stdout: false,
        dry_run: false,
        all: false
      }
    end

    def run
      parse_options
      client = Obsidian.new(vault: @options[:vault])

      selected_paths = gather_selection(client)
      return 1 unless selected_paths
      return no_selection if selected_paths.empty?

      if @options[:dry_run]
        print_dry_run(selected_paths, client)
        return 0
      end

      files = read_selected_files(client, selected_paths)
      bundle = Bundle.new(files).to_markdown
      write_output(bundle)
      0
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
      ui.show_error "#{@app_name}: #{e.message}"
      @stderr.puts "Run `bin/#{@app_name} --help` for usage."
      2
    rescue Obsidian::CommandNotFound => e
      ui.show_error "#{@app_name}: #{e.message}"
      @stderr.puts "Install/enable Obsidian CLI, or set OBSCTX_OBSIDIAN to its path."
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

        opts.on("-q", "--query QUERY", "Obsidian search query. Default: #{DEFAULT_QUERY}") do |value|
          @options[:query] = value
        end

        opts.on("-v", "--vault VAULT", "Obsidian vault name or id") do |value|
          @options[:vault] = value
        end

        opts.on("--stdout", "Print stitched context instead of copying to clipboard") do
          @options[:stdout] = true
        end

        opts.on("--dry-run", "Show selected files and estimated bundle size") do
          @options[:dry_run] = true
        end

        opts.on("--all", "Include all search results without opening the picker") do
          @options[:all] = true
        end

        opts.on("-h", "--help", "Show this help") do
          @stdout.puts opts
          exit 0
        end
      end

      parser.parse!(@argv)
    end

    def gather_selection(client)
      query = @options[:query] || prompt_for_query

      loop do
        paths = client.search(query)
        return no_results_for_selection(query) if paths.empty?

        selection = select_paths(paths, query:)
        return selection.paths unless selection.new_query

        query = selection.new_query
      end
    end

    def prompt_for_query
      return DEFAULT_QUERY unless interactive?

      ui.prompt_query(default: DEFAULT_QUERY)
    end

    def select_paths(paths, query:)
      return TUI::Selection.new(paths:, new_query: nil) if @options[:all]

      unless interactive?
        raise Obsidian::CommandFailed,
              "interactive selection requires a TTY; rerun with --all or provide input from a terminal"
      end

      ui.select(paths, query:)
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

      _out, err, status = Open3.capture3("pbcopy", stdin_data: bundle)
      raise Obsidian::CommandFailed, "pbcopy failed: #{err.strip}" unless status.success?

      ui.show_copied(bundle.bytesize)
    end

    def no_results_for_selection(query)
      ui.show_no_results(query)
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
