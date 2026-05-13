# Release: ARCHiTEXT v0.1.6

ARCHiTEXT `v0.1.6` is the first polished patch rollup after the initial release. It keeps the original product shape intact while tightening cross-platform behavior, vault setup, and Windows terminal reliability.

## Highlights

- Native clipboard support across macOS, Windows, and Linux.
- Persistent default vault controls with `--set-default-vault` and `--clear-default-vault`.
- Startup diagnostics via `architext --diagnose`.
- More explicit vault source labels in prompts and selector UI.
- Reliable Windows Obsidian CLI search capture through PowerShell.
- JSON-first Obsidian search parsing with UTF-8 output normalization.
- Windows selector redraw fixes for PowerShell and Windows Terminal.
- Arrow-key handling for byte-by-byte and combined escape sequences.
- Emoji and wide Unicode-aware path truncation in the selector.

## Verification

- Tested on macOS and Windows with the native `architext` flow.
- CI covers macOS, Ubuntu, and Windows.
