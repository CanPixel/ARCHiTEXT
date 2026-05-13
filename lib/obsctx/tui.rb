# frozen_string_literal: true

require 'io/console'

require_relative 'terminal'
require_relative 'version'

module ObsidianContext
  # rubocop:disable Metrics/ClassLength
  class TUI
    HELP = '↑/k ↓/j move  space select  a all  / filter  n new search  v vault  enter confirm  q quit'
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

    def initialize(stdin:, stdout:, stderr:, app_name:)
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
      @app_name = app_name
      @color = Terminal.enabled?(@stdout)
      @intro_rendered = false
    end

    def prompt_query(default:)
      draw_intro
      @stdout.print render("[bold][cyan]Search query[/] [dim](default: #{default})[/]: ")
      input = @stdin.gets&.strip
      input.nil? || input.empty? ? default : input
    end

    # rubocop:disable Metrics/BlockLength
    def select(paths, query:, vault:)
      state = {
        query: query,
        vault: vault,
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
    # rubocop:enable Metrics/BlockLength

    def show_no_results(query, vault:)
      vault_label = vault.to_s.strip.empty? ? '[dim]active vault: (default)[/]' : "[dim]active vault:[/] [cyan]#{vault}[/]"
      @stderr.puts render("[red]No Obsidian notes matched[/] [amber]#{query.inspect}[/]  #{vault_label}")
      @stderr.puts render('[amber]Tip:[/] press [bold]v[/] in the TUI to set a vault, or pass [bold]--vault[/].')
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
        version = "v#{ObsidianContext::VERSION}"
        styled_version = version_style ? Terminal.paint(version, version_style, enabled: @color) : version
        @stdout.puts center(styled_version, width)
        @stdout.puts
        @stdout.flush
        sleep(0.08) if frames.length > 1
      end
    end

    def with_screen
      use_alt_screen = Terminal.alt_screen_supported?(@stdout)
      @stdout.write Terminal::ALT_SCREEN if use_alt_screen
      @stdout.write Terminal::HIDE_CURSOR
      yield
    ensure
      @stdout.write Terminal::SHOW_CURSOR
      @stdout.write Terminal::MAIN_SCREEN if use_alt_screen
    end

    def draw_selector(paths:, visible:, state:)
      height, width = terminal_size
      list_height = [height - 13, 5].max
      keep_cursor_visible!(state, visible.length, list_height:)
      rows = visible.drop(state[:offset]).first(list_height)

      @stdout.write Terminal::HOME
      @stdout.write Terminal::CLEAR

      draw_header(width, state, paths.length, visible.length)
      draw_panel_top(width, 'Context Candidates')

      rows.each_with_index do |path, index|
        absolute_index = state[:offset] + index
        active = absolute_index == state[:cursor]
        checked = state[:selected][path]
        marker = checked ? '●' : '○'
        pointer = active ? '▶' : ' '
        style = if active
                  :inverse
                else
                  checked ? :green : :ink
                end
        line = " #{pointer} #{marker} #{path}"
        @stdout.puts panel_line(Terminal.paint(Terminal.truncate(line, width - 4), style, enabled: @color), width)
      end

      empty_rows = list_height - rows.length
      empty_rows.times { @stdout.puts panel_line('', width) }

      draw_panel_bottom(width)
      draw_status(width, state, visible.length)
      @stdout.flush
    end

    def draw_header(width, state, total, visible_count)
      @stdout.puts render("[cyan]#{LOGO.first}[/]")
      @stdout.puts render('[bold]ARCHiTEXT[/] [dim]knowledge graph extraction console[/]')
      vault_label = state[:vault].to_s.strip.empty? ? '[dim](default)[/]' : "[cyan]#{state[:vault]}[/]"
      @stdout.puts render("[dim]vault:[/] #{vault_label}")
      @stdout.puts render("[dim]query:[/] [amber]#{state[:query]}[/]  [dim]filter:[/] [cyan]#{state[:filter].empty? ? 'none' : state[:filter]}[/]")
      @stdout.puts render("[dim]results:[/] #{visible_count}/#{total}  [dim]selected:[/] #{state[:selected].length}")
      @stdout.puts Terminal.paint('─' * width, :faint, enabled: @color)
    end

    def draw_panel_top(width, title)
      @stdout.puts Terminal.paint("╭─ #{title} #{'─' * [width - title.length - 6, 0].max}╮", :blue, enabled: @color)
    end

    def draw_panel_bottom(width)
      @stdout.puts Terminal.paint("╰#{'─' * [width - 2, 0].max}╯", :blue, enabled: @color)
    end

    def panel_line(content, width)
      inner_width = [width - 4, 1].max
      visible = Terminal.visible_length(content)
      padding = ' ' * [inner_width - visible, 0].max
      Terminal.paint('│ ', :blue, enabled: @color) + content + padding + Terminal.paint(' │', :blue, enabled: @color)
    end

    def draw_status(width, state, visible_count)
      @stdout.puts render("[dim]#{HELP}[/]")
      detail = if visible_count.zero?
                 '[amber]No visible results. Press / to change filter or n for a new search.[/]'
               elsif state[:selected].empty?
                 '[dim]Select one or more notes, then press enter.[/]'
               else
                 "[green]Ready:[/] #{state[:selected].length} note(s) selected."
               end
      @stdout.puts Terminal.truncate(render(detail), width)
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
      list_height ||= [terminal_size.first - 13, 5].max
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

      if windows_extended_key_prefix?(key)
        parse_windows_extended_key
      elsif key == "\e"
        parse_escape_key
      else
        :unknown
      end
    end

    def windows_extended_key_prefix?(key)
      ["\u0000", "\u00E0"].include?(key)
    end

    def parse_windows_extended_key
      case @stdin.getch
      when 'H'
        :up
      when 'P'
        :down
      else
        :unknown
      end
    end

    def parse_escape_key
      sequence = read_escape_sequence

      case sequence
      when /\A\[A/
        :up
      when /\A\[B/
        :down
      else
        :unknown
      end
    end

    def read_escape_sequence
      sequence = +''

      loop do
        sequence << @stdin.read_nonblock(1)
      rescue IO::WaitReadable, EOFError
        break
      end

      sequence
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
  end
  # rubocop:enable Metrics/ClassLength
end
