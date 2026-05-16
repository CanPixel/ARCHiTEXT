# frozen_string_literal: true

require_relative 'selection_parser'

module Architext
  class Picker
    def initialize(stdin:, stdout:)
      @stdin = stdin
      @stdout = stdout
    end

    def select(paths)
      tty_prompt_select(paths) || fallback_select(paths)
    end

    private

    def tty_prompt_select(paths)
      require 'tty-prompt'

      prompt = TTY::Prompt.new(input: @stdin, output: @stdout)
      prompt.multi_select('Select notes to include:', paths, per_page: 20)
    rescue LoadError
      nil
    end

    def fallback_select(paths)
      @stdout.puts 'Select notes to include:'
      paths.each_with_index do |path, index|
        @stdout.puts "#{index + 1}. #{path}"
      end

      @stdout.puts
      @stdout.print 'Enter numbers, ranges, or all (example: 1,3-5): '
      input = @stdin.gets&.strip.to_s
      SelectionParser.new(paths).parse(input)
    end
  end
end
