# frozen_string_literal: true

module Architext
  FileContent = Data.define(:path, :content)

  class Bundle
    def initialize(files)
      @files = files
    end

    def to_markdown
      sections = @files.map do |file|
        normalized = file.content.to_s.chomp
        "## File: #{file.path}\n\n#{normalized}"
      end

      "# Context Bundle\n\n#{sections.join("\n\n---\n\n")}\n"
    end
  end
end
