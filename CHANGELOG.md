# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2026-05-13

### Added
- Startup vault configuration flow: type `v` at search prompt to open vault config mode.
- Clear startup vault diagnostics showing:
  - active vault and source
  - saved default vault
  - default vault config path
- No-results diagnostics now include vault source, config path, and Obsidian CLI executable reference.

### Changed
- Gem package name normalized to lowercase `architext` for `gem install/uninstall architext`.
- Context selection header now shows explicit vault source labels (`--vault`, `saved default`, `session`, `obsidian default`).
- `(default)` vault label replaced with clearer "none selected (obsidian default)" messaging.

## [0.1.1] - 2026-05-13

### Added
- Cross-platform clipboard support for macOS, Windows, and Linux command-line environments.
- `--version` flag to print the running executable version.
- Windows and Linux platform notes in README.
- CI matrix coverage for `ubuntu-latest`, `macos-latest`, and `windows-latest`.
- Persistent default vault management via `--set-default-vault` and `--clear-default-vault`.
- TUI vault control (`v`) plus active-vault visibility in the selector header.
- Splash intro enhancements: branded subtitle, centered version line, and short glow animation.

### Changed
- TUI input handling for better Windows key compatibility.
- Terminal capability detection to avoid unsupported rendering features in some terminals.
- `q` during selection now returns to the search prompt instead of exiting immediately.
- No-results feedback now includes vault context and remediation tips.

## [0.1.0] - 2026-05-13

### Added
- Initial release of `architext`.
- TUI for interactive Obsidian note selection.
- CLI support for queries and vault selection.
- GitHub Actions CI workflow.
- Professional repository documentation (`CHANGELOG.md`).
- RuboCop integration for linting.
- `bin/setup` script for easier development environment configuration.
