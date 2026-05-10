# frozen_string_literal: true

module ObsidianContext
  module Terminal
    RESET = "\e[0m"
    HIDE_CURSOR = "\e[?25l"
    SHOW_CURSOR = "\e[?25h"
    CLEAR = "\e[2J"
    HOME = "\e[H"
    ALT_SCREEN = "\e[?1049h"
    MAIN_SCREEN = "\e[?1049l"

    PALETTE = {
      ink: "\e[38;2;221;231;239m",
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

    TAGS = PALETTE.transform_keys(&:to_s).merge("/" => RESET).freeze

    module_function

    def enabled?(io = $stdout)
      io.respond_to?(:tty?) && io.tty? && ENV["NO_COLOR"].nil?
    end

    def paint(text, *styles, enabled: true)
      return text.to_s unless enabled

      styles.map { |style| PALETTE.fetch(style) }.join + text.to_s + RESET
    end

    # Tiny pretext-style renderer: "[cyan]text[/]" keeps visual markup readable.
    def render(markup, enabled: true)
      return strip_markup(markup) unless enabled

      markup.to_s.gsub(/\[(\/|[a-z_]+)\]/) { TAGS.fetch(Regexp.last_match(1), Regexp.last_match(0)) }
    end

    def strip_markup(markup)
      markup.to_s.gsub(/\[(\/|[a-z_]+)\]/, "")
    end

    def visible_length(text)
      text.to_s.gsub(/\e\[[0-9;?]*[A-Za-z]/, "").length
    end

    def truncate(text, width)
      plain = text.to_s
      return "" if width <= 0
      return plain if visible_length(plain) <= width

      stripped = plain.gsub(/\e\[[0-9;?]*[A-Za-z]/, "")
      return stripped[0, width] if width <= 1

      "#{stripped[0, width - 1]}…"
    end
  end
end
