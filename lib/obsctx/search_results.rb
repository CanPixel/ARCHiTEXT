# frozen_string_literal: true

require 'json'

module ObsidianContext
  class SearchResults
    def self.parse(output)
      new(output).parse
    end

    def initialize(output)
      @output = normalize_output(output)
    end

    def parse
      parsed = JSON.parse(@output)
      paths_from_json(parsed).uniq
    rescue JSON::ParserError
      paths_from_text(@output).uniq
    end

    private

    def paths_from_json(value)
      paths = case value
              when Array
                value.flat_map { |entry| paths_from_json(entry) }
              when Hash
                [hash_path(value), *paths_from_nested_hash(value)]
              when String
                [clean_path(value)]
              else
                []
              end

      paths.compact
    end

    def paths_from_nested_hash(hash)
      %w[results matches files items].flat_map do |key|
        paths_from_json(hash[key] || hash[key.to_sym])
      end
    end

    def hash_path(hash)
      path = hash['path'] || hash[:path] || hash['file'] || hash[:file]
      clean_path(path) if path
    end

    def paths_from_text(text)
      text.lines.filter_map { |line| clean_path(line) }
    end

    def clean_path(value)
      path = value.to_s.strip
      return nil if path.empty?

      path
    end

    def normalize_output(output)
      text = output.to_s.dup
      text.force_encoding(Encoding::UTF_8)
      text.valid_encoding? ? text : text.scrub
    end
  end
end
