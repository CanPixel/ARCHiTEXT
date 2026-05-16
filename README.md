# ARCHiTEXT

<p align="center">
  <img src="assets/logo.svg" alt="ARCHiTEXT Logo" width="200">
  <br>
  <b>The bridge between your Obsidian vault and LLMs.</b>
  <br>
  <i>A high-performance Ruby TUI for context stitching.</i>
</p>

<p align="center">
  <a href="https://github.com/CanPixel/ARCHiTEXT/actions/workflows/ci.yml">
    <img src="https://github.com/CanPixel/ARCHiTEXT/actions/workflows/ci.yml/badge.svg" alt="CI Status">
  </a>
  <a href="https://rubygems.org/gems/architext">
    <img src="https://img.shields.io/badge/version-v0.2.0-5BE8B8.svg" alt="Version 0.2.0">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License">
  </a>
  <img src="https://img.shields.io/badge/maintained-yes-green.svg" alt="Maintained">
</p>

---

<img src="assets/social-preview.svg" alt="ARCHiTEXT Social Preview" width="1080">

As LLM context windows grow, the way we feed them data **needs to scale**.

`ARCHiTEXT` is a standalone Ruby TUI for stitching Obsidian notes into an LLM-friendly Markdown context bundle. It uses the official `obsidian` CLI as the source of truth for vault search and file reads, providing a visual terminal interface for selecting notes.

## 🚀 Quick Start

```sh
# Start the interactive search and selection flow
architext
```

ARCHiTEXT will detect your active Obsidian vault, ask for a search query, then open a picker where you can select notes and copy the stitched context bundle to your clipboard.

Common next steps:

```sh
# Search with a specific query
architext --query "game"

# Search a specific vault
architext --vault "Main Vault" --query "project"

# Print the bundle instead of copying it
architext --query "tag:#project/active" --all --stdout
```

## ✨ Features

- **Visual Picker:** Interactively select notes using a high-performance ANSI TUI.
- **Vault-Aware UX:** Active vault is always visible in the TUI, with inline vault switching.
- **Context Stitching:** Automatically bundles selected notes into a single Markdown file.
- **LLM Ready:** Output is formatted specifically for easy consumption by AI agents.
- **No Dependencies:** Built-in ANSI-based TUI logic (no complex visual gems required).
- **Cross-Platform Clipboard:** Uses native clipboard commands on macOS, Windows, and Linux.

## 📦 Installation

### Using RubyGems

```sh
gem install architext
architext --version
```

### Uninstall

```sh
gem uninstall architext
```

### From Source

```sh
git clone https://github.com/CanPixel/ARCHiTEXT.git
cd ARCHiTEXT
./bin/setup
ruby bin/architext --version
gem build architext.gemspec
gem install ./architext-*.gem
```

## ⚙️ Configuration

Architext relies on the [Obsidian CLI](https://github.com/obsidianmd/obsidian-cli). Ensure it is installed and available on your `PATH`.

### Supported Platforms

- **macOS:** Fully supported (tested in CI).
- **Windows:** Native terminal support (PowerShell/Windows Terminal) with `clip` clipboard integration.
- **Linux:** Native terminal support with clipboard integration via `wl-copy`, `xclip`, or `xsel`.

### Setting the Obsidian CLI Path

If the CLI is not in your `PATH`, you can set the `ARCHITEXT_OBSIDIAN` environment variable:

```sh
export ARCHITEXT_OBSIDIAN="/path/to/obsidian"
```

PowerShell:

```powershell
$env:ARCHITEXT_OBSIDIAN = "C:\path\to\obsidian.exe"
```

## 🛠 Usage

```sh
# Basic interactive search
architext

# Search with a specific query
architext --query "Zombie Parkour"

# Output directly to stdout (useful for piping)
architext --query "tag:#ctx/current" --stdout | gemini "Summarize this"

# Specify a vault
architext --vault "Main Vault" --query "Ideas"

# Set a persistent default vault
architext --set-default-vault "Main Vault"

# Clear the persistent default vault
architext --clear-default-vault

# Check exactly which executable version is running
architext --version

# Print vault/CLI diagnostics before searching
architext --diagnose

# Skip the picker and include all results
architext --query "tag:#project/active" --all --stdout
```

### Vault Selection Behavior

- `--vault` sets the vault only for the current run.
- `--set-default-vault` stores a persistent default vault for future runs.
- If `--vault` is omitted, the persistent default vault is used when available.
- At the search prompt, type `v` to open vault configuration mode.
- Press `v` in the TUI selection screen to change vault inline for the current session.
- The active vault is shown in the TUI header (`vault: ...`) so target scope is always visible.
- Vault path resolution is performed by the Obsidian CLI (`vault=<name_or_id>`); ARCHiTEXT displays the vault reference and source.
- Startup prompt includes an Obsidian connection check (`version`, resolved vault summary, executable path).

### Search Prompt Controls

| Input | Action |
| --- | --- |
| `enter` | Run search with default query |
| `v` | Open vault configuration screen |
| `q` | Quit |

### TUI Controls

| Key | Action |
| --- | --- |
| `↑`/`k`, `↓`/`j` | Move selection |
| `space` | Toggle selection for current note |
| `a` | Toggle all visible notes |
| `/` | Filter current results |
| `n` | Start a new Obsidian search |
| `v` | Set/change active vault |
| `enter` | Confirm and bundle selected notes |
| `q` | Return to search prompt |

## 🔍 Troubleshooting

### Obsidian CLI Not Found
If you see an error about `obsidian` command not found:
1. Ensure the Obsidian desktop app is installed.
2. Verify that you have installed the `obsidian` CLI tool.
3. Check if `obsidian` is in your `PATH` by running `which obsidian` (macOS/Linux) or `where obsidian` (Windows).
4. If you previously exported `OBSCTX_OBSIDIAN`, rename it to `ARCHITEXT_OBSIDIAN`.

### Command Not Found After Gem Install
If `gem install architext` succeeds but `architext` is not found, your Ruby executable directory is not on your shell `PATH`.

1. Find RubyGems executable directory:
   - `gem env | grep "EXECUTABLE DIRECTORY"`
2. Add that directory to your shell `PATH` (for `zsh`, update `~/.zshrc`).
3. Restart your shell and verify:
   - `which architext`
   - `architext --version`

### No Results But Notes Exist
- Verify the active vault shown in the TUI header.
- At the search prompt, type `v` to open vault configuration.
- In selection, use `v` to switch vault and rerun the query.
- Set a persistent vault with `--set-default-vault "Your Vault"`.
- For one-off runs, pass `--vault "Your Vault"` explicitly.
- Run `architext --diagnose` to print the exact vault reference/source and Obsidian CLI resolution before searching.

### Clipboard Issues
Architext auto-detects clipboard tools:
- macOS: `pbcopy`
- Windows: `clip` (fallback: PowerShell `Set-Clipboard`)
- Linux: `wl-copy`, `xclip`, or `xsel`

If none are available, run with `--stdout` and pipe output to your preferred clipboard manager.

## 📜 License

Architext is released under the [MIT License](LICENSE).
