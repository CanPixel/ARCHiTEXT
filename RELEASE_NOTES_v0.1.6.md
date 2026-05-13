# Release: ARCHiTEXT v0.1.6

ARCHiTEXT `v0.1.6` hardens the context candidate selector for Windows PowerShell and Windows Terminal.

## Fixed

- Replaced the full-width boxed selector with a fixed-height no-wrap layout so emoji-heavy Obsidian paths cannot wrap and corrupt the redraw.
- Arrow keys now work when Ruby receives a full escape sequence from `getch`, not only when the sequence arrives byte by byte.
- Candidate path truncation now accounts for common wide Unicode and emoji characters.

## Verification

- `ruby -Ilib test\obsctx_test.rb`
- `ruby -Ilib bin\architext --vault OBSIDIAN-MAIN --query "Stone Shooters" --all --dry-run`
