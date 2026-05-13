# Release: ARCHiTEXT v0.1.4

ARCHiTEXT `v0.1.4` fixes Windows Obsidian CLI capture from Ruby.

## Fixed

- Windows now routes Obsidian CLI calls through PowerShell before capturing output. This avoids the `Obsidian.com` behavior where a direct Ruby `Open3.capture3` call receives only a newline even though the same command prints search results in an interactive PowerShell terminal.

## Verification

- `ruby -Ilib test\obsctx_test.rb`
- `ruby -Ilib -e "require 'obsctx/obsidian'; client = ObsidianContext::Obsidian.new(vault: 'OBSIDIAN-MAIN'); paths = client.search('Game'); puts paths.length"`
- `ruby -Ilib bin\architext --vault OBSIDIAN-MAIN --query "Stone Shooters" --all --dry-run`
