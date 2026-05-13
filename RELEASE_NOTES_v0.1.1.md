# Release: ARCHiTEXT v0.1.1

ARCHiTEXT `v0.1.1` is a platform and UX-focused release that improves Windows/Linux compatibility, clarifies vault targeting, and tightens day-to-day operator feedback in the TUI.

## Highlights

### Cross-Platform Support
- Added clipboard support across:
  - macOS (`pbcopy`)
  - Windows (`clip`, fallback `Set-Clipboard`)
  - Linux (`wl-copy`, `xclip`, `xsel`)
- Improved terminal capability handling for better behavior outside macOS defaults.
- Expanded CI to validate on `ubuntu-latest`, `macos-latest`, and `windows-latest`.

### Vault UX and Control
- Added persistent default vault controls:
  - `--set-default-vault "Vault Name"`
  - `--clear-default-vault`
- Kept `--vault` as a per-run override.
- Added in-TUI vault switching with `v`.
- Added active vault visibility in the TUI header.
- Improved no-results messaging to include active vault context and remediation hints.

### TUI Flow Improvements
- Pressing `q` in selection now returns to the main search prompt (instead of exiting immediately).
- Added `--version` for explicit runtime version checks.

### Branding and Visual Polish
- Updated splash subtitle text to:
  - `Architect Obsidian context and stitch for agent work`
- Added centered version display on splash intro.
- Updated title styling to `ARCHiTEXT`.
- Added a short intro glow animation on boot.

### Documentation and Assets
- Updated README usage and troubleshooting for:
  - default vault workflow
  - TUI controls (`v`, updated `q` behavior)
  - version verification
- Updated social preview SVG tagline and title casing to match current branding.

## Upgrade Notes

- If you previously relied on global vault defaults outside the app, you can now manage this natively with:
  - `architext --set-default-vault "Your Vault"`
- To confirm the executable you are running:
  - `architext --version`

## Validation

- Test suite passes with expanded coverage (`23` tests).
- RuboCop passes with no offenses.
- Cross-platform CI matrix is configured to guard against regressions.
