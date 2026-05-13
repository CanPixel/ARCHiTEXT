# Architext

<p align="center">
  <img src="https://raw.githubusercontent.com/CanPixel/ARCHiTEXT/master/assets/logo.png" alt="Architext Logo" width="200">
  <br>
  <b>The bridge between your Obsidian vault and LLMs.</b>
  <br>
  <i>A high-performance Ruby TUI for context stitching.</i>
</p>

<p align="center">
  <a href="https://github.com/CanPixel/architext/actions/workflows/ci.yml">
    <img src="https://github.com/CanPixel/architext/actions/workflows/ci.yml/badge.svg" alt="CI Status">
  </a>
  <a href="https://rubygems.org/gems/architext">
    <img src="https://img.shields.io/gem/v/architext.svg" alt="Gem Version">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License">
  </a>
  <img src="https://img.shields.io/badge/maintained-yes-green.svg" alt="Maintained">
</p>

---

`architext` is a standalone Ruby TUI for stitching Obsidian notes into an LLM-friendly Markdown context bundle. It uses the official `obsidian` CLI as the source of truth for vault search and file reads, providing a visual terminal interface for selecting notes.

## 🚀 Quick Start

```sh
# Search for notes tagged with #project/active and copy to clipboard
architext --query "tag:#project/active"
```

## ✨ Features

- **Visual Picker:** Interactively select notes using a high-performance ANSI TUI.
- **Context Stitching:** Automatically bundles selected notes into a single Markdown file.
- **LLM Ready:** Output is formatted specifically for easy consumption by AI agents.
- **No Dependencies:** Built-in ANSI-based TUI logic (no complex visual gems required).
- **Clipboard Integration:** Copies directly to macOS clipboard by default.

## 📦 Installation

### Using RubyGems

```sh
gem install architext
```

### From Source

```sh
git clone https://github.com/CanPixel/architext.git
cd architext
./bin/setup
gem build architext.gemspec
gem install ./architext-*.gem
```

## ⚙️ Configuration

Architext relies on the [Obsidian CLI](https://github.com/obsidianmd/obsidian-cli). Ensure it is installed and available on your `PATH`.

### Setting the Obsidian CLI Path

If the CLI is not in your `PATH`, you can set the `OBSCTX_OBSIDIAN` environment variable:

```sh
export OBSCTX_OBSIDIAN="/path/to/obsidian"
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

# Skip the picker and include all results
architext --query "tag:#project/active" --all --stdout
```

### TUI Controls

| Key | Action |
| --- | --- |
| `↑`/`k`, `↓`/`j` | Move selection |
| `space` | Toggle selection for current note |
| `a` | Toggle all visible notes |
| `/` | Filter current results |
| `n` | Start a new Obsidian search |
| `enter` | Confirm and bundle selected notes |
| `q` | Quit |

## 🔍 Troubleshooting

### Obsidian CLI Not Found
If you see an error about `obsidian` command not found:
1. Ensure the Obsidian desktop app is installed.
2. Verify that you have installed the `obsidian` CLI tool.
3. Check if `obsidian` is in your `PATH` by running `which obsidian`.

### macOS Clipboard Issues
Architext uses `pbcopy` for clipboard integration. If you are using Linux or WSL, use the `--stdout` flag and pipe to your system's clipboard manager (e.g., `xclip` or `wl-copy`).

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to get started.

## 📜 License

Architext is released under the [MIT License](LICENSE).
