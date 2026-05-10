# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "architext"
  spec.version = "0.1.0"
  spec.summary = "A visual Obsidian context stitching TUI for agent workflows."
  spec.description = "A terminal interface to interactively select and bundle Obsidian notes for AI agent context."
  spec.homepage = "https://github.com/can/architext" # Placeholder
  spec.authors = ["Can"]
  spec.files = Dir["bin/*", "lib/**/*.rb", "README.md"]
  spec.executables = ["architext", "obsctx"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.2"
  spec.license = "MIT"

  spec.metadata["allowed_push_host"] = "https://example.invalid"

  spec.add_dependency "tty-prompt", "~> 0.23"
end
