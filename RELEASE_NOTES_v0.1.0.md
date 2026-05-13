# Release: ARCHiTEXT v0.1.0 (Initial Release) 🚀

We are thrilled to announce the first official release of **Architext**, a high-performance Ruby TUI designed to be the bridge between your Obsidian vault and Large Language Models (LLMs).

## 💡 The Vision
Modern AI agents thrive on context, but gathering that context manually from a sprawling Obsidian vault is tedious. Architext transforms this process into a seamless, visual experience. It allows you to search, filter, and "stitch" multiple notes into a single, structured Markdown bundle that agents can consume immediately.

## ✨ Key Features in v0.1.0
- **Interactive TUI Picker:** A fast, ANSI-based terminal interface for selecting notes without leaving your workflow.
- **Smart Context Stitching:** Automatically formats selected notes into a single, clean Markdown file with clear file headers.
- **Obsidian CLI Integration:** Uses the official `obsidian` CLI as the source of truth for vault operations.
- **Zero-Dependency TUI:** Built from the ground up with native Ruby and ANSI escape codes—no heavy visual gems required.
- **Agent-Ready Output:** Default behavior copies the bundle to your clipboard, or you can pipe it directly into other CLI tools (like `gemini-cli`).
- **Flexible Search:** Supports vault-specific searches and complex queries (e.g., searching by tags).

## 📦 Installation
Get started by installing the gem:
```bash
gem install architext
```

Or run it directly from source:
```bash
git clone https://github.com/CanPixel/ARCHiTEXT.git
cd architext
./bin/setup
architext
```

## 🛠 Usage Example
Search for active project notes and pipe them into an LLM for a summary:
```bash
architext --query "tag:#project/active" --stdout | gemini "What are my immediate next steps?"
```


---


# Patch: ARCHiTEXT v0.1.6

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

Check out the [README.md](https://github.com/CanPixel/ARCHiTEXT/blob/master/README.md) for full documentation.

---
**Enjoying ARCHiTEXT?** Star us on GitHub and share your workflows with us!

