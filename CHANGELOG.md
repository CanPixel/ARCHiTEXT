# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v1.0.0.html).

## [1.0.0] - 2026-05-29

### Added
- Native markdown folder source is now the default, searching `.md` and `.markdown` files under the current directory or `--root`.
- `--source native|obsidian` and `--root PATH` flags for explicit source selection.
- Native search support for plain terms, quoted phrases, `tag:`, `path:`, and `file:` query tokens.

### Changed
- Obsidian CLI integration is now optional and explicit via `--source obsidian` or legacy `--vault`.
- TUI and diagnostics now use source/root language and only show Obsidian CLI details in Obsidian mode.
- README and gem metadata now position ARCHiTEXT as a markdown context stitching tool.

## [0.2.0] - 2026-05-16

### Changed
- Naming normalization release: align gem/library/executable naming around `architext` following RubyGems consistent naming guidance.
- Rename internal Ruby namespace from `ObsidianContext` to `Architext`.
- Rename library layout from `lib/obsctx/*` to `lib/architext/*` with `lib/architext.rb` as the canonical entrypoint.
- Standardize executable usage on `bin/architext` and remove the legacy `obsctx` executable from the gem package.
- Standardize Obsidian CLI override environment variable on `ARCHITEXT_OBSIDIAN`.

## [0.1.6] - 2026-05-13

### Fixed
- Replace the Windows selector frame with a fixed-height, no-wrap layout to prevent redraw fragments from accumulating in PowerShell.
- Handle arrow-key escape sequences returned as a single `getch` value as well as byte-by-byte sequences.
- Account for emoji and wide Unicode characters when truncating candidate paths.

## [0.1.5] - 2026-05-13

### Fixed
- Smooth selector redraws on Windows by using the alternate screen and repainting the frame in place instead of clearing the whole terminal on every navigation key.
- Improve arrow-key parsing for Windows PowerShell and other VT-style terminals.

## [0.1.4] - 2026-05-13

### Fixed
- Route Obsidian CLI calls through PowerShell on Windows so Ruby captures the same search output shown in an interactive terminal.

## [0.1.3] - 2026-05-13

### Fixed
- Prefer Obsidian CLI `format=json` search output before text output, matching the reliable Windows CLI path.
- Normalize captured Obsidian CLI output as UTF-8 before parsing so emoji-heavy Windows vault paths survive Ruby process capture.

## [0.1.2] - 2026-05-13

### Added
- Startup vault configuration flow: type `v` at search prompt to open vault config mode.
- Clear startup vault diagnostics showing:
  - active vault and source
  - saved default vault
  - default vault config path
- Obsidian CLI pre-search connection diagnostics (`version`, resolved vault summary, executable path).
- `--diagnose` CLI flag to print vault/CLI connection details without running a search.
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
