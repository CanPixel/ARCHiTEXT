# frozen_string_literal: true

require 'rbconfig'

module ObsidianContext
  module Terminal
    RESET = "\e[0m"
    HIDE_CURSOR = "\e[?25l"
    SHOW_CURSOR = "\e[?25h"
    CLEAR = "\e[2J"
    CLEAR_TO_END = "\e[J"
    CLEAR_LINE = "\e[2K"
    HOME = "\e[H"
    ALT_SCREEN = "\e[?1049h"
    MAIN_SCREEN = "\e[?1049l"

    PALETTE = {
      ink: "\e[38;2;221;231;239m",
      white: "\e[38;2;255;255;255m",
      dim: "\e[38;2;126;140;155m",
      faint: "\e[38;2;83;96;112m",
      cyan: "\e[38;2;91;220;255m",
      blue: "\e[38;2;98;151;255m",
      green: "\e[38;2;91;232;184m",
      amber: "\e[38;2;245;196;94m",
      red: "\e[38;2;255;104;112m",
      violet: "\e[38;2;190;142;255m",
      bold: "\e[1m",
      inverse: "\e[7m"
    }.freeze

    TAGS = PALETTE.transform_keys(&:to_s).merge('/' => RESET).freeze

    module_function

    def enabled?(io = $stdout)
      io.respond_to?(:tty?) && io.tty? && ENV['NO_COLOR'].nil? && !dumb_terminal?
    end

    def alt_screen_supported?(io = $stdout)
      enabled?(io) && ENV['ARCHITEXT_NO_ALT_SCREEN'].nil?
    end

    def paint(text, *styles, enabled: true)
      return text.to_s unless enabled

      styles.map { |style| PALETTE.fetch(style) }.join + text.to_s + RESET
    end

    # Tiny pretext-style renderer: "[cyan]text[/]" keeps visual markup readable.
    def render(markup, enabled: true)
      return strip_markup(markup) unless enabled

      markup.to_s.gsub(%r{\[(/|[a-z_]+)\]}) { TAGS.fetch(Regexp.last_match(1), Regexp.last_match(0)) }
    end

    def strip_markup(markup)
      markup.to_s.gsub(%r{\[(/|[a-z_]+)\]}, '')
    end

    def visible_length(text)
      display_width(strip_ansi(text))
    end

    def truncate(text, width)
      plain = text.to_s
      return '' if width <= 0
      return plain if visible_length(plain) <= width

      truncate_plain(strip_ansi(plain), width)
    end

    def strip_ansi(text)
      text.to_s.gsub(/\e\[[0-9;?]*[A-Za-z]/, '')
    end

    def truncate_plain(text, width)
      return '' if width <= 0
      return text.to_s if display_width(text) <= width
      return text.to_s.each_char.first.to_s if width <= 1

      out = +''
      used = 0
      text.to_s.each_char do |char|
        char_width = char_display_width(char)
        break if used + char_width > width - 3

        out << char
        used += char_width
      end
      "#{out}..."
    end

    def display_width(text)
      text.to_s.each_char.sum { |char| char_display_width(char) }
    end

    def char_display_width(char)
      codepoint = char.ord
      return 0 if codepoint < 32 || codepoint == 0x7F
      return 0 if combining_mark?(codepoint)
      return 2 if wide_codepoint?(codepoint)

      1
    end

    def combining_mark?(codepoint)
      (0x0300..0x036F).cover?(codepoint) ||
        (0x1AB0..0x1AFF).cover?(codepoint) ||
        (0x1DC0..0x1DFF).cover?(codepoint) ||
        (0x20D0..0x20FF).cover?(codepoint) ||
        (0xFE00..0xFE0F).cover?(codepoint)
    end

    def wide_codepoint?(codepoint)
      (0x1100..0x115F).cover?(codepoint) ||
        (0x2329..0x232A).cover?(codepoint) ||
        (0x2E80..0xA4CF).cover?(codepoint) ||
        (0xAC00..0xD7A3).cover?(codepoint) ||
        (0xF900..0xFAFF).cover?(codepoint) ||
        (0xFE10..0xFE19).cover?(codepoint) ||
        (0xFE30..0xFE6F).cover?(codepoint) ||
        (0xFF00..0xFF60).cover?(codepoint) ||
        (0xFFE0..0xFFE6).cover?(codepoint) ||
        (0x1F000..0x1FAFF).cover?(codepoint)
    end

    def dumb_terminal?
      ENV.fetch('TERM', '').downcase == 'dumb'
    end

    def windows?
      host_os = RbConfig::CONFIG['host_os'].to_s.downcase
      host_os.match?(/mswin|mingw|cygwin/)
    end
  end
end
