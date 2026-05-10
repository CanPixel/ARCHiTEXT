# frozen_string_literal: true

module ObsidianContext
  class SelectionParser
    def initialize(paths)
      @paths = paths
    end

    def parse(input)
      normalized = input.to_s.strip.downcase
      return @paths if %w[a all *].include?(normalized)
      return [] if normalized.empty?

      indexes = normalized.split(",").flat_map { |part| expand_part(part.strip) }
      indexes.uniq.filter_map { |index| @paths[index - 1] }
    end

    private

    def expand_part(part)
      if part.match?(/\A\d+\z/)
        [part.to_i]
      elsif (match = part.match(/\A(\d+)\s*-\s*(\d+)\z/))
        first = match[1].to_i
        last = match[2].to_i
        first <= last ? (first..last).to_a : (last..first).to_a
      else
        []
      end
    end
  end
end
