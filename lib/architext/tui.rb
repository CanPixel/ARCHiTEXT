# frozen_string_literal: true

require 'io/console'

require_relative 'terminal'
require_relative 'version'

module Architext
  # rubocop:disable Metrics/ClassLength
  class TUI
    HELP = 'Up/k Down/j move  space select  a all  / filter  n new search  v vault  enter confirm  q back'
    KEY_BINDINGS = {
      ' ' => :space,
      'k' => :up,
      'j' => :down,
      'a' => :all,
      '/' => :filter,
      'n' => :new_query,
      'v' => :new_vault,
      'q' => :quit
    }.freeze
    LOGO = [
      '    ___              __    _ __            __ ',
      '   /   |  __________/ /_  (_) /____  _  __/ /_',
      '  / /| | / ___/ ___/ __ \\/ / __/ _ \\| |/_/ __/',
      ' / ___ |/ /  / /__/ / / / / /_/  __/>  </ /_  ',
      '/_/  |_/_/   \\___/_/ /_/_/\\__/\\___/_/|_|\\__/  '
    ].freeze

    Selection = Data.define(:paths, :new_query, :new_vault, :reprompt_query)
    QueryPrompt = Data.define(:query, :open_vault_config, :quit)
    VaultConfigAction = Data.define(:session_vault, :set_default_vault, :clear_default, :back)

    def initialize(stdin:, stdout:, stderr:, app_name:)
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
      @app_name = app_name
      @color = Terminal.enabled?(@stdout)
      @intro_rendered = false
    end

    def prompt_query(default:, context:)
      draw_intro
      draw_startup_vault_status(
        context[:vault],
        context[:vault_source],
        context[:default_vault],
        context[:default_vault_path],
        context[:connection_report]
      )
      @stdout.print render("[bold][cyan]Search query[/] [dim](default: #{default})[/] [dim]| type 'v' for vault config, 'q' to quit:[/] ")
      input = @stdin.gets&.strip
      return QueryPrompt.new(query: nil, open_vault_config: false, quit: true) if input.nil?

      normalized = input.strip
      return QueryPrompt.new(query: nil, open_vault_config: true, quit: false) if %w[v /v vault /vault].include?(normalized.downcase)
      return QueryPrompt.new(query: nil, open_vault_config: false, quit: true) if %w[q /q quit /quit].include?(normalized.downcase)

      QueryPrompt.new(query: normalized.empty? ? default : normalized, open_vault_config: false, quit: false)
    end

    # rubocop:disable Metrics/AbcSize
    def prompt_vault_config(active_vault:, active_vault_source:, default_vault:, default_vault_path:)
      draw_intro
      @stdout.puts render('[bold][cyan]Vault Configuration[/]')
      @stdout.puts render("[dim]active:[/] #{format_vault_label(active_vault, active_vault_source)}")
      @stdout.puts render("[dim]saved default:[/] #{format_saved_default(default_vault)}")
      @stdout.puts render("[dim]default config path:[/] #{default_vault_path}")
      @stdout.puts render('[dim]vault path resolution is handled by Obsidian CLI via vault=<name_or_id>.[/]')
      @stdout.puts
      @stdout.puts render('[dim]Commands:[/]')
      @stdout.puts render('  [cyan]use <vault>[/] [dim]set active vault for this run[/]')
      @stdout.puts render('  [cyan]save <vault>[/] [dim]save persistent default vault[/]')
      @stdout.puts render('  [cyan]clear[/] [dim]clear persistent default vault[/]')
      @stdout.puts render('  [cyan]none[/] [dim]clear active vault (use Obsidian CLI default)[/]')
      @stdout.puts render('  [cyan]back[/] [dim]return to search prompt[/]')
      @stdout.puts
      @stdout.print render('[bold][cyan]vault-config[/]> ')
      input = @stdin.gets&.strip
      return VaultConfigAction.new(session_vault: nil, set_default_vault: nil, clear_default: false, back: true) if input.nil?

      command = input.strip
      return VaultConfigAction.new(session_vault: nil, set_default_vault: nil, clear_default: false, back: true) if command.empty?
      return VaultConfigAction.new(session_vault: nil, set_default_vault: nil, clear_default: false, back: true) if command.casecmp('back').zero?
      return VaultConfigAction.new(session_vault: '', set_default_vault: nil, clear_default: false, back: false) if command.casecmp('none').zero?
      return VaultConfigAction.new(session_vault: nil, set_default_vault: nil, clear_default: true, back: false) if command.casecmp('clear').zero?

      if (match = command.match(/\Asave\s+(.+)\z/i))
        return VaultConfigAction.new(session_vault: nil, set_default_vault: match[1].strip, clear_default: false, back: false)
      end

      if (match = command.match(/\Ause\s+(.+)\z/i))
        return VaultConfigAction.new(session_vault: match[1].strip, set_default_vault: nil, clear_default: false, back: false)
      end

      VaultConfigAction.new(session_vault: command, set_default_vault: nil, clear_default: false, back: false)
    end
    # rubocop:enable Metrics/AbcSize

    # rubocop:disable Metrics/BlockLength, Metrics/MethodLength
    def select(paths, query:, vault:, vault_source:)
      state = {
        query: query,
        vault: vault,
        vault_source: vault_source,
        filter: '',
        cursor: 0,
        offset: 0,
        selected: {}
      }

      with_screen do
        loop do
          visible = filtered_paths(paths, state[:filter])
          clamp_cursor!(state, visible.length)
          draw_selector(paths:, visible:, state:)

          case read_key
          when :up
            state[:cursor] -= 1
          when :down
            state[:cursor] += 1
          when :space
            toggle_current(visible, state)
          when :all
            toggle_all(visible, state)
          when :filter
            state[:filter] = prompt_inline('Filter visible results', state[:filter])
          when :new_query
            return Selection.new(
              paths: [],
              new_query: prompt_inline('New Obsidian search', state[:query]),
              new_vault: nil,
              reprompt_query: false
            )
          when :new_vault
            return Selection.new(
              paths: [],
              new_query: nil,
              new_vault: prompt_inline('Vault name or id (blank clears)', state[:vault].to_s),
              reprompt_query: false
            )
          when :enter
            selected = selected_paths(paths, state)
            return Selection.new(paths: selected, new_query: nil, new_vault: nil, reprompt_query: false)
          when :quit
            return Selection.new(paths: [], new_query: nil, new_vault: nil, reprompt_query: true)
          when :ctrl_c
            return Selection.new(paths: [], new_query: nil, new_vault: nil, reprompt_query: false)
          end

          clamp_cursor!(state, visible.length)
          keep_cursor_visible!(state, visible.length)
        end
      end
    end
    # rubocop:enable Metrics/BlockLength, Metrics/MethodLength

    def show_no_results(query, vault:, vault_source:, default_vault_path:, obsidian_executable:)
      vault_label = format_vault_label(vault, vault_source)
      @stderr.puts render("[red]No Obsidian notes matched[/] [amber]#{query.inspect}[/]  #{vault_label}")
      @stderr.puts render("[dim]default vault config:[/] #{default_vault_path}")
      @stderr.puts render("[dim]obsidian cli:[/] #{obsidian_executable}")
      @stderr.puts render('[amber]Tip:[/] at search prompt type [bold]v[/] for vault config, or pass [bold]--vault[/].')
    end

    def show_no_selection
      @stderr.puts render('[amber]No files selected.[/]')
    end

    def show_copied(bytes)
      @stdout.puts render("[green]Copied[/] [bold]#{bytes} bytes[/] [dim]to clipboard.[/]")
    end

    def show_error(message)
      @stderr.puts render("[red]#{message}[/]")
    end

    def show_info(message)
      @stdout.puts render("[green]#{message}[/]")
    end

    def show_dry_run(selected_paths, bytes)
      draw_intro
      @stdout.puts render("[bold][green]Dry run[/] [dim]#{selected_paths.length} selected file(s)[/]")
      @stdout.puts
      selected_paths.each { |path| @stdout.puts render("  [cyan]•[/] #{path}") }
      @stdout.puts
      @stdout.puts render("[dim]Estimated context size:[/] [bold]#{bytes} bytes[/]")
    end

    private

    def draw_intro
      return unless @stdout.tty?
      return if @intro_rendered

      width = terminal_size.last
      play_intro_animation(width)
      @intro_rendered = true
    end

    def play_intro_animation(width)
      frames = @color ? [%i[faint dim], %i[blue dim], %i[cyan white]] : [[nil, nil]]

      frames.each do |logo_style, version_style|
        @stdout.write Terminal::HOME
        @stdout.write Terminal::CLEAR
        @stdout.puts
        LOGO.each do |line|
          styled = logo_style ? Terminal.paint(line, logo_style, enabled: @color) : line
          @stdout.puts center(styled, width)
        end
        @stdout.puts center(render('[dim]Architect Obsidian context and stitch for agent work[/]'), width)
        version = "v#{Architext::VERSION}"
        styled_version = version_style ? Terminal.paint(version, version_style, enabled: @color) : version
        @stdout.puts center(styled_version, width)
        @stdout.puts
        @stdout.flush
        sleep(0.08) if frames.length > 1
      end
    end

    def with_screen
      use_alt_screen = Terminal.alt_screen_supported?(@stdout)
      @selector_frame_started = false
      @stdout.write Terminal::ALT_SCREEN if use_alt_screen
      @stdout.write Terminal::HIDE_CURSOR
      @stdout.write Terminal::HOME
      @stdout.write Terminal::CLEAR
      yield
    ensure
      @stdout.write Terminal::SHOW_CURSOR
      @stdout.write Terminal::MAIN_SCREEN if use_alt_screen
      @selector_frame_started = false
    end

    def draw_selector(paths:, visible:, state:)
      height, terminal_width = terminal_size
      width = usable_width(terminal_width)
      list_height = [height - 8, 5].max
      keep_cursor_visible!(state, visible.length, list_height:)
      rows = visible.drop(state[:offset]).first(list_height)
      lines = []

      lines.concat(header_lines(width, state, paths.length, visible.length))
      lines << section_title(width, 'Context Candidates')

      rows.each_with_index do |path, index|
        absolute_index = state[:offset] + index
        active = absolute_index == state[:cursor]
        checked = state[:selected][path]
        marker = checked ? '[x]' : '[ ]'
        pointer = active ? '>' : ' '
        style = if active
                  :inverse
                else
                  checked ? :green : :ink
                end
        line = "#{pointer} #{marker} #{path}"
        truncated = Terminal.truncate(line, width)
        lines << Terminal.paint(truncated, style, enabled: @color)
      end

      empty_rows = list_height - rows.length
      empty_rows.times { lines << '' }

      lines.concat(status_lines(width, state, visible.length))
      frame = lines.map { |line| clear_line(line) }.join("\n")

      @stdout.write Terminal::HOME
      @stdout.write(@selector_frame_started ? Terminal::CLEAR_TO_END : Terminal::CLEAR)
      @stdout.write frame
      @stdout.write Terminal::CLEAR_TO_END
      @stdout.flush
      @selector_frame_started = true
    end

    def header_lines(width, state, total, visible_count)
      filter_label = state[:filter].empty? ? 'none' : state[:filter]
      [
        Terminal.truncate(render("[bold][cyan]ARCHiTEXT[/] [dim]#{state[:vault] || 'obsidian default'}[/]"), width),
        Terminal.truncate(render("[dim]query:[/] [amber]#{state[:query]}[/]  [dim]filter:[/] [cyan]#{filter_label}[/]"), width),
        Terminal.truncate(render("[dim]results:[/] #{visible_count}/#{total}  [dim]selected:[/] #{state[:selected].length}"), width),
        Terminal.paint('-' * width, :faint, enabled: @color)
      ]
    end

    def section_title(width, title)
      Terminal.paint(Terminal.truncate("-- #{title} ", width), :blue, enabled: @color)
    end

    def status_lines(width, state, visible_count)
      detail = if visible_count.zero?
                 '[amber]No visible results. Press / to change filter or n for a new search.[/]'
               elsif state[:selected].empty?
                 '[dim]Select one or more notes, then press enter.[/]'
               else
                 "[green]Ready:[/] #{state[:selected].length} note(s) selected."
               end
      [
        Terminal.paint('-' * width, :faint, enabled: @color),
        Terminal.truncate(render("[dim]#{HELP}[/]"), width),
        Terminal.truncate(render(detail), width)
      ]
    end

    def clear_line(text)
      "#{Terminal::CLEAR_LINE}\r#{text}"
    end

    def usable_width(width)
      (width.to_i - 2).clamp(40, 160)
    end

    def prompt_inline(label, current)
      @stdout.write Terminal::SHOW_CURSOR
      @stdout.print render("\n[bold][cyan]#{label}[/] [dim](blank keeps current)[/]: ")
      input = @stdin.gets&.strip
      @stdout.write Terminal::HIDE_CURSOR
      input.nil? || input.empty? ? current : input
    end

    def filtered_paths(paths, filter)
      needle = filter.to_s.downcase
      return paths if needle.empty?

      paths.select { |path| path.downcase.include?(needle) }
    end

    def selected_paths(paths, state)
      paths.select { |path| state[:selected][path] }
    end

    def toggle_current(visible, state)
      path = visible[state[:cursor]]
      return unless path

      state[:selected][path] ? state[:selected].delete(path) : state[:selected][path] = true
    end

    def toggle_all(visible, state)
      return if visible.empty?

      all_selected = visible.all? { |path| state[:selected][path] }
      visible.each do |path|
        all_selected ? state[:selected].delete(path) : state[:selected][path] = true
      end
    end

    def clamp_cursor!(state, count)
      max = [count - 1, 0].max
      state[:cursor] = state[:cursor].clamp(0, max)
    end

    def keep_cursor_visible!(state, count, list_height: nil)
      list_height ||= [terminal_size.first - 8, 5].max
      state[:offset] = state[:offset].clamp(0, [count - list_height, 0].max)
      state[:offset] = state[:cursor] if state[:cursor] < state[:offset]
      return unless state[:cursor] >= state[:offset] + list_height

      state[:offset] = state[:cursor] - list_height + 1
    end

    def read_key
      key = @stdin.getch
      return :ctrl_c if key == "\u0003"

      return :enter if ["\r", "\n"].include?(key)

      mapped = KEY_BINDINGS[key]
      return mapped if mapped

      bytes = key.to_s.bytes
      if bytes.first == 27 && bytes.length > 1
        parse_escape_sequence(bytes[1..])
      elsif windows_extended_combo?(key)
        parse_windows_extended_code(bytes[1])
      elsif windows_extended_key_prefix?(key)
        parse_windows_extended_key
      elsif key == "\e"
        parse_escape_key
      else
        :unknown
      end
    end

    def windows_extended_key_prefix?(key)
      [0, 224].include?(key.to_s.bytes.first)
    end

    def windows_extended_combo?(key)
      key.to_s.bytes.length > 1 && windows_extended_key_prefix?(key)
    end

    def parse_windows_extended_key
      parse_windows_extended_code(@stdin.getch)
    end

    def parse_windows_extended_code(code)
      case code_byte(code)
      when 72
        :up
      when 80
        :down
      else
        :unknown
      end
    end

    def parse_escape_key
      parse_escape_sequence(read_escape_sequence)
    end

    def parse_escape_sequence(sequence)
      text = sequence.is_a?(Array) ? sequence.pack('C*') : sequence.to_s

      case text
      when /\A(?:\[A|OA)/
        :up
      when /\A(?:\[B|OB)/
        :down
      else
        :unknown
      end
    end

    def read_escape_sequence
      sequence = []
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 0.08

      loop do
        sequence.concat(@stdin.read_nonblock(8).bytes)
        break if escape_sequence_complete?(sequence)
      rescue IO::WaitReadable, EOFError
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.005
      rescue NotImplementedError
        sequence.concat(read_escape_sequence_with_getch)
        break
      end

      sequence
    end

    def escape_sequence_complete?(sequence)
      sequence.pack('C*').match?(/\A(?:O[A-D]|\[[0-9;?]*[A-Za-z~])\z/)
    end

    def read_escape_sequence_with_getch
      bytes = []
      2.times do
        key = @stdin.getch
        bytes.concat(key.to_s.bytes)
        break if escape_sequence_complete?(bytes)
      rescue EOFError
        break
      end
      bytes
    end

    def code_byte(value)
      return value if value.is_a?(Integer)

      value.to_s.bytes.first
    end

    def terminal_size
      @stdout.winsize
    rescue StandardError
      [28, 100]
    end

    def center(text, width)
      visible = Terminal.visible_length(text)
      "#{' ' * [(width - visible) / 2, 0].max}#{text}"
    end

    def render(markup)
      Terminal.render(markup, enabled: @color)
    end

    def draw_startup_vault_status(vault, vault_source, default_vault, default_vault_path, connection_report)
      @stdout.puts render("[dim]active vault:[/] #{format_vault_label(vault, vault_source)}")
      @stdout.puts render("[dim]saved default:[/] #{format_saved_default(default_vault)}")
      @stdout.puts render("[dim]default config path:[/] #{default_vault_path}")
      @stdout.puts render("[dim]obsidian cli:[/] #{connection_report[:executable]}")
      @stdout.puts render("[dim]obsidian version:[/] #{connection_report[:version] || 'unknown'}")
      status_style = connection_report[:status] == 'ok' ? '[green]ok[/]' : '[red]error[/]'
      @stdout.puts render("[dim]connection check:[/] #{status_style}")
      @stdout.puts render("[dim]resolved vault:[/] #{connection_report[:resolved_vault_summary]}") if connection_report[:resolved_vault_summary]
      @stdout.puts render("[amber]diagnostic:[/] #{connection_report[:warning]}") if connection_report[:warning]
      @stdout.puts render('[dim]vault target semantics: CWD vault if inside one, otherwise active Obsidian vault unless overridden.[/]')
      @stdout.puts
    end

    def format_vault_label(vault, source)
      return "[amber]none selected[/] [dim](#{source})[/]" if vault.to_s.strip.empty?

      "[cyan]#{vault}[/] [dim](#{source})[/]"
    end

    def format_saved_default(default_vault)
      return '[dim]none[/]' if default_vault.to_s.strip.empty?

      "[cyan]#{default_vault}[/]"
    end
  end
  # rubocop:enable Metrics/ClassLength
end
