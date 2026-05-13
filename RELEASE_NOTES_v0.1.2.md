# Release: ARCHiTEXT v0.1.2

ARCHiTEXT `v0.1.2` improves first-run vault UX and Windows setup ergonomics.

## Highlights

### Packaging / Install Ergonomics
- Gem package name is now lowercase: `architext`.
- RubyGems install/uninstall now matches command naming:
  - `gem install architext`
  - `gem uninstall architext`

### Startup Vault Configuration Flow
- At search prompt, typing `v` now opens a dedicated vault configuration screen.
- Vault configuration screen shows:
  - active vault and source
  - saved default vault
  - default vault config file path
  - how vault resolution works
- Supported config actions:
  - `use <vault>`
  - `save <vault>`
  - `clear`
  - `none`
  - `back`

### Vault Visibility / Diagnostics
- Active vault now displays with explicit source labels:
  - `--vault`
  - `saved default`
  - `session`
  - `obsidian default`
- Startup shows Obsidian CLI connection status before search:
  - executable path/reference
  - CLI version
  - resolved vault summary from `obsidian vault`
  - mismatch warning when requested vault may not match resolved vault
- No-results output now includes:
  - active vault and source
  - default vault config path
  - Obsidian CLI executable reference
- Replaced ambiguous `(default)` wording with clearer vault-state messaging.
- Added `--diagnose` to print vault/CLI diagnostics without running a search.

### Reliability
- Fixed dry-run code path to construct Obsidian client correctly.
- Added tests for startup search prompt controls (`v`, `q`).

## Notes on Vault Resolution

Vault directory resolution is handled by the Obsidian CLI itself.  
ARCHiTEXT passes the vault reference as `vault=<name_or_id>` and displays the reference/source in UI.
