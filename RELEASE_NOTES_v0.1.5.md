# Release: ARCHiTEXT v0.1.5

ARCHiTEXT `v0.1.5` improves selector interaction in Windows terminals.

## Fixed

- The context candidate selector now uses the terminal alternate screen when available, including modern Windows PowerShell sessions, so navigation no longer pushes the main terminal scrollback downward.
- Selector redraws now repaint a single fixed frame in place instead of clearing the full screen on every `j`/`k` or arrow-key movement.
- Arrow-key parsing now waits briefly for the rest of VT escape sequences, which makes up/down arrows work more reliably in PowerShell and Windows Terminal.

## Escape Hatch

- Set `ARCHITEXT_NO_ALT_SCREEN=1` to force the old main-screen rendering mode.
