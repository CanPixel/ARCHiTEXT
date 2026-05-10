# architext

`architext` is a standalone Ruby TUI for stitching Obsidian notes into an
LLM-friendly Markdown context bundle.

It uses the official `obsidian` CLI as the source of truth for vault search and
file reads, then gives you a visual terminal interface for selecting notes. The
result can be copied to the macOS clipboard or printed to stdout.

`bin/obsctx` still exists as a compatibility alias, but `bin/architext` is the
primary command.

## Requirements

- Ruby 3.x
- Obsidian CLI on `PATH`
- Obsidian desktop app installed and configured for CLI access
- macOS `pbcopy` for default clipboard output

The app uses its own ANSI-based visual TUI by default, including ASCII art,
colors, panels, keyboard navigation, and a small pretext-style markup renderer.
No visual gem is required to run it.

## Usage

```sh
bin/architext
bin/architext --query "tag:#project/active"
bin/architext --query "Zombie Parkour" --stdout
bin/architext --vault "Main Vault" --query "tag:#ctx/current"
bin/architext --query "tag:#project/active" --dry-run
```

To install the command locally as `architext`:

```sh
gem build architext.gemspec
gem install ./architext-0.1.0.gem
architext
```

By default, the stitched bundle is copied to the clipboard. Use `--stdout` when
you want to pipe it into another tool:

```sh
bin/architext --query "tag:#project/active" --stdout | gemini "Summarize this context"
```

Use `--all` to skip the picker and include every search result:

```sh
bin/architext --query "tag:#ctx/current" --all --stdout
```

## TUI Controls

```text
↑/k ↓/j   move
space     select note
a         toggle all visible notes
/         filter current results
n         run a new Obsidian search
enter     confirm selection
q         quit
```

## Output Format

```md
# Context Bundle

## File: path/to/note.md

note contents...
```

## Development

Run the tests:

```sh
ruby test/obsctx_test.rb
```
