# frozen_string_literal: true

require_relative "lib/architext/version"

Gem::Specification.new do |spec|
  spec.name = "architext"
  spec.version = Architext::VERSION
  spec.summary = "A visual markdown context stitching TUI for agent workflows."
  spec.description = "A terminal interface to interactively search, select, and bundle markdown notes for AI agent context."
  spec.homepage = "https://github.com/CanPixel/ARCHiTEXT#readme"
  spec.authors = ["Can"]
  spec.files = %w[LICENSE README.md CHANGELOG.md] + Dir["bin/*", "lib/**/*.rb"]
  spec.bindir = "bin"
  spec.executables = ["architext"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.2"
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/CanPixel/ARCHiTEXT"
  spec.metadata["bug_tracker_uri"] = "https://github.com/CanPixel/ARCHiTEXT/issues"
  spec.metadata["changelog_uri"] = "https://github.com/CanPixel/ARCHiTEXT/blob/master/CHANGELOG.md"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "tty-prompt", "~> 0.23"

  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "rubocop-minitest", "~> 0.34"
  spec.add_development_dependency "rubocop-rake", "~> 0.6"
  spec.add_development_dependency "minitest", "~> 5.0"
end
