# Release: ARCHiTEXT v0.1.3

ARCHiTEXT `v0.1.3` fixes Windows Obsidian search result capture.

## Fixed

- Search now asks `obsidian search` for `format=json` first, then falls back to text only when JSON returns no paths.
- Captured Obsidian CLI output is normalized as UTF-8 before parsing, which protects emoji-heavy note paths on Windows.
