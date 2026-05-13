# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "architext"
  spec.version = "0.1.0"
  spec.summary = "A visual Obsidian context stitching TUI for agent workflows."
  spec.description = "A terminal interface to interactively select and bundle Obsidian notes for AI agent context."
  spec.homepage = "https://github.com/CanPixel/architext" # Placeholder
  spec.authors = ["Can"]
  spec.files = Dir["bin/*", "lib/**/*.rb", "README.md"]
  spec.executables = ["architext", "obsctx"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.2"
  spec.license = "MIT"

  spec.metadata["allowed_push_host"] = "https://example.invalid"

  spec.add_dependency "tty-prompt", "~> 0.23"

  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "rubocop-minitest", "~> 0.34"
  spec.add_development_dependency "rubocop-rake", "~> 0.6"
  spec.add_development_dependency "minitest", "~> 5.0"
end
