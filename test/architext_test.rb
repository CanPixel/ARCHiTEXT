# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'stringio'
require 'tmpdir'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'architext/bundle'
require 'architext/clipboard'
require 'architext/cli'
require 'architext/search_results'
require 'architext/selection_parser'
require 'architext/settings'
require 'architext/sources'
require 'architext/terminal'
require 'architext/tui'

module Architext
  class SearchResultsTest < Minitest::Test
    def test_parses_json_array_of_paths
      output = JSON.dump(['Ideas/Game.md', 'Plans/Roadmap.md'])

      assert_equal ['Ideas/Game.md', 'Plans/Roadmap.md'], SearchResults.parse(output)
    end

    def test_parses_json_objects_with_paths
      output = JSON.dump([{ 'path' => 'Ideas/Game.md' }, { 'file' => 'Plans/Roadmap.md' }])

      assert_equal ['Ideas/Game.md', 'Plans/Roadmap.md'], SearchResults.parse(output)
    end

    def test_parses_nested_result_arrays
      output = JSON.dump({ 'results' => [{ 'path' => 'Ideas/Game.md' }] })

      assert_equal ['Ideas/Game.md'], SearchResults.parse(output)
    end

    def test_falls_back_to_line_based_text
      output = "Ideas/Game.md\n\nPlans/Roadmap.md\n"

      assert_equal ['Ideas/Game.md', 'Plans/Roadmap.md'], SearchResults.parse(output)
    end

    def test_parses_utf8_json_output_tagged_with_windows_encoding
      output = JSON.dump(['🕹️ GAMES/Game.md']).b
      output.force_encoding(Encoding::Windows_1252)

      assert_equal ['🕹️ GAMES/Game.md'], SearchResults.parse(output)
    end
  end

  class ObsidianTest < Minitest::Test
    def test_search_prefers_json_before_text_output
      Dir.mktmpdir do |dir|
        executable = build_json_required_obsidian(dir)

        client = Obsidian.new(executable:)

        assert_equal ['Ideas/Game.md'], client.search('game')
      end
    end

    private

    def build_json_required_obsidian(dir)
      if Gem.win_platform?
        script_path = File.join(dir, 'obsidian.rb')
        launcher_path = File.join(dir, 'obsidian.cmd')
        File.write(script_path, json_required_obsidian_script)
        File.write(launcher_path, "@echo off\r\nruby \"%~dp0obsidian.rb\" %*\r\n")
        return launcher_path
      end

      executable = File.join(dir, 'obsidian')
      File.write(executable, json_required_obsidian_script)
      FileUtils.chmod('+x', executable)
      executable
    end

    def json_required_obsidian_script
      <<~RUBY
        #!/usr/bin/env ruby
        # frozen_string_literal: true

        require "json"

        if ARGV.include?("format=text")
          warn "text output unavailable"
          exit 2
        end

        puts JSON.dump(["Ideas/Game.md"])
      RUBY
    end
  end

  class NativeMarkdownSourceTest < Minitest::Test
    def test_discovers_markdown_recursively_and_excludes_junk_directories
      with_notes do |dir|
        write_note(dir, 'Projects/Alpha.md', '# Alpha')
        write_note(dir, 'Journal/Beta.markdown', '# Beta')
        write_note(dir, 'misc.txt', '# Text')
        write_note(dir, '.git/Hidden.md', '# Hidden')
        write_note(dir, 'node_modules/Package.md', '# Package')
        write_note(dir, '.bundle/Gem.md', '# Gem')
        write_note(dir, 'vendor/Vendored.md', '# Vendored')

        assert_equal ['Journal/Beta.markdown', 'Projects/Alpha.md'], NativeMarkdownSource.new(root: dir).search('')
      end
    end

    def test_plain_text_matches_path_or_content
      with_notes do |dir|
        write_note(dir, 'Projects/Alpha.md', 'Planning the launch')
        write_note(dir, 'Journal/Beta.md', 'Unrelated')

        assert_equal ['Projects/Alpha.md'], NativeMarkdownSource.new(root: dir).search('launch')
        assert_equal ['Projects/Alpha.md'], NativeMarkdownSource.new(root: dir).search('alpha')
      end
    end

    def test_quoted_phrases_and_multiple_terms_are_and_matched
      with_notes do |dir|
        write_note(dir, 'Projects/Alpha.md', 'the exact project phrase with launch')
        write_note(dir, 'Projects/Beta.md', 'the exact project phrase without it')

        assert_equal ['Projects/Alpha.md'], NativeMarkdownSource.new(root: dir).search('"exact project phrase" launch')
      end
    end

    def test_tag_path_and_file_operators
      with_notes do |dir|
        write_note(dir, 'Projects/Alpha.md', "#project/active\nLaunch note")
        write_note(dir, 'Archive/Alpha.md', "#project/archive\nOld note")
        source = NativeMarkdownSource.new(root: dir)

        assert_equal ['Projects/Alpha.md'], source.search('tag:#project/active')
        assert_equal ['Archive/Alpha.md', 'Projects/Alpha.md'], source.search('tag:project')
        assert_equal ['Projects/Alpha.md'], source.search('path:Projects')
        assert_equal ['Archive/Alpha.md', 'Projects/Alpha.md'], source.search('file:Alpha')
      end
    end

    def test_read_rejects_paths_that_escape_root
      with_notes do |dir|
        source = NativeMarkdownSource.new(root: dir)

        assert_raises(SourceError) { source.read('../outside.md') }
      end
    end

    private

    def with_notes(&)
      Dir.mktmpdir(&)
    end

    def write_note(root, path, content)
      full_path = File.join(root, path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
    end
  end

  class SelectionParserTest < Minitest::Test
    PATHS = ['one.md', 'two.md', 'three.md', 'four.md'].freeze

    def test_parses_numbers_and_ranges
      selected = SelectionParser.new(PATHS).parse('1,3-4')

      assert_equal ['one.md', 'three.md', 'four.md'], selected
    end

    def test_reversed_ranges_are_supported
      selected = SelectionParser.new(PATHS).parse('3-2')

      assert_equal ['two.md', 'three.md'], selected
    end

    def test_all_selects_everything
      assert_equal PATHS, SelectionParser.new(PATHS).parse('all')
    end

    def test_invalid_and_out_of_range_values_are_ignored
      selected = SelectionParser.new(PATHS).parse('2,nope,99')

      assert_equal ['two.md'], selected
    end
  end

  class BundleTest < Minitest::Test
    def test_builds_stable_markdown_bundle
      files = [
        FileContent.new(path: 'one.md', content: "First\n"),
        FileContent.new(path: 'two.md', content: 'Second')
      ]

      expected = <<~MARKDOWN
        # Context Bundle

        ## File: one.md

        First

        ---

        ## File: two.md

        Second
      MARKDOWN

      assert_equal expected, Bundle.new(files).to_markdown
    end
  end

  class TerminalTest < Minitest::Test
    def test_render_strips_markup_when_color_is_disabled
      rendered = Terminal.render('[cyan]Architext[/] [dim]ready[/]', enabled: false)

      assert_equal 'Architext ready', rendered
    end

    def test_render_includes_ansi_when_color_is_enabled
      rendered = Terminal.render('[cyan]Architext[/]', enabled: true)

      assert_includes rendered, "\e[38;2;91;220;255m"
      assert_includes rendered, Terminal::RESET
    end

    def test_visible_length_counts_emoji_as_wide
      assert_equal 4, Terminal.visible_length('a🎮b')
    end

    def test_truncate_respects_wide_characters
      truncated = Terminal.truncate('a🎮bcdef', 5)

      assert_operator Terminal.visible_length(truncated), :<=, 5
      assert_equal 'a...', truncated
    end
  end

  class TUITest < Minitest::Test
    def test_prompt_query_accepts_v_for_vault_config
      stdin = StringIO.new("v\n")
      stdout = StringIO.new
      stderr = StringIO.new
      tui = TUI.new(stdin:, stdout:, stderr:, app_name: 'architext')

      result = tui.prompt_query(
        default: 'tag:#project/active',
        context: {
          source: 'native',
          root: '/notes',
          root_source: 'current folder',
          vault: nil,
          vault_source: 'obsidian default',
          default_vault: nil,
          default_vault_path: '/tmp/default_vault',
          connection_report: {
            source: 'native',
            root: '/notes',
            vault: nil,
            vault_source: nil,
            status: 'ok',
            markdown_count: 2,
            executable: nil,
            version: nil,
            resolved_vault_summary: nil,
            warning: nil
          }
        }
      )

      assert result.open_vault_config
      refute result.quit
      assert_nil result.query
      assert_includes stdout.string, 'active source: /notes (root)'
      assert_includes stdout.string, 'type \'v\' for source config'
    end

    def test_prompt_query_accepts_q_to_quit
      stdin = StringIO.new("q\n")
      stdout = StringIO.new
      stderr = StringIO.new
      tui = TUI.new(stdin:, stdout:, stderr:, app_name: 'architext')

      result = tui.prompt_query(
        default: 'tag:#project/active',
        context: {
          source: 'native',
          root: '/notes',
          root_source: 'current folder',
          vault: nil,
          vault_source: 'obsidian default',
          default_vault: nil,
          default_vault_path: '/tmp/default_vault',
          connection_report: {
            source: 'native',
            root: '/notes',
            vault: nil,
            vault_source: nil,
            status: 'ok',
            markdown_count: 2,
            executable: nil,
            version: nil,
            resolved_vault_summary: nil,
            warning: nil
          }
        }
      )

      assert result.quit
      refute result.open_vault_config
      assert_nil result.query
    end

    def test_read_key_accepts_vt_arrow_up
      assert_equal :up, tui_for_keys(["\e", '[', 'A']).send(:read_key)
    end

    def test_read_key_accepts_application_cursor_arrow_down
      assert_equal :down, tui_for_keys(["\e", 'O', 'B']).send(:read_key)
    end

    def test_read_key_accepts_windows_extended_arrow_up
      assert_equal :up, tui_for_keys(["\xE0".b, 'H']).send(:read_key)
    end

    def test_read_key_accepts_windows_extended_arrow_down
      assert_equal :down, tui_for_keys(["\xE0".b, 'P']).send(:read_key)
    end

    def test_read_key_accepts_combined_windows_extended_arrow_down
      assert_equal :down, tui_for_keys(["\xE0P".b]).send(:read_key)
    end

    def test_read_key_accepts_combined_vt_arrow_down
      assert_equal :down, tui_for_keys(["\e[B"]).send(:read_key)
    end

    private

    class FakeKeyInput
      def initialize(keys)
        @keys = keys.dup
      end

      def getch
        @keys.shift || raise(EOFError)
      end

      def read_nonblock(_length)
        @keys.shift || raise(EOFError)
      end
    end

    def tui_for_keys(keys)
      TUI.new(stdin: FakeKeyInput.new(keys), stdout: StringIO.new, stderr: StringIO.new, app_name: 'architext')
    end
  end

  # rubocop:disable Metrics/ClassLength
  class CLITest < Minitest::Test
    def test_stdout_all_uses_native_markdown_search_by_default
      with_notes do |dir|
        write_note(dir, 'Ideas/Game.md', "#ctx/current\nContents for game")
        write_note(dir, 'Plans/Roadmap.md', 'Other note')
        stdout = StringIO.new
        stderr = StringIO.new

        code = chdir(dir) do
          CLI.new(
            ['--query', 'tag:#ctx/current', '--all', '--stdout'],
            io: { stdout:, stderr: }
          ).run
        end

        assert_equal 0, code
        assert_empty stderr.string
        assert_includes stdout.string, '# Context Bundle'
        assert_includes stdout.string, '## File: Ideas/Game.md'
        assert_includes stdout.string, 'Contents for game'
      end
    end

    def test_root_selects_a_native_markdown_folder
      with_notes do |dir|
        write_note(dir, 'Ideas/Game.md', 'selected root note')
        stdout = StringIO.new
        stderr = StringIO.new

        code = CLI.new(
          ['--root', dir, '--query', 'selected', '--all', '--stdout'],
          io: { stdout:, stderr: }
        ).run

        assert_equal 0, code
        assert_empty stderr.string
        assert_includes stdout.string, '## File: Ideas/Game.md'
      end
    end

    def test_source_obsidian_uses_obsidian_search_and_read
      with_fake_obsidian do |obsidian_path|
        stdout = StringIO.new
        stderr = StringIO.new

        code = with_env('ARCHITEXT_OBSIDIAN' => obsidian_path) do
          CLI.new(
            ['--source', 'obsidian', '--query', 'tag:#ctx/current', '--all', '--stdout'],
            io: { stdout:, stderr: }
          ).run
        end

        assert_equal 0, code
        assert_empty stderr.string
        assert_includes stdout.string, '# Context Bundle'
        assert_includes stdout.string, '## File: Ideas/Game.md'
        assert_includes stdout.string, 'Contents for Ideas/Game.md'
        assert_includes stdout.string, '## File: Plans/Roadmap.md'
      end
    end

    def test_vault_flag_implies_obsidian_source
      with_fake_obsidian do |obsidian_path|
        stdout = StringIO.new
        stderr = StringIO.new

        code = with_env('ARCHITEXT_OBSIDIAN' => obsidian_path) do
          CLI.new(
            ['--vault', 'Main Vault', '--query', 'game', '--all', '--stdout'],
            io: { stdout:, stderr: }
          ).run
        end

        assert_equal 0, code
        assert_empty stderr.string
        assert_includes stdout.string, '## File: Ideas/Game.md'
      end
    end

    def test_read_failure_returns_error
      with_fake_obsidian(search_paths: ['Ideas/Game.md', 'bad.md']) do |obsidian_path|
        stdout = StringIO.new
        stderr = StringIO.new

        code = with_env('ARCHITEXT_OBSIDIAN' => obsidian_path) do
          CLI.new(
            ['--source', 'obsidian', '--query', 'tag:#ctx/current', '--all', '--stdout'],
            io: { stdout:, stderr: }
          ).run
        end

        assert_equal 1, code
        assert_empty stdout.string
        assert_includes stderr.string, 'Obsidian command failed'
      end
    end

    def test_no_results_returns_error_without_extra_no_selection_message
      with_notes do |dir|
        stdout = StringIO.new
        stderr = StringIO.new

        code = chdir(dir) do
          CLI.new(
            ['--query', 'tag:#missing', '--all', '--stdout'],
            io: { stdout:, stderr: },
            app_name: 'architext'
          ).run
        end

        assert_equal 1, code
        assert_empty stdout.string
        assert_includes stderr.string, 'No markdown notes matched'
        refute_includes stderr.string, 'No files selected'
      end
    end

    def test_non_stdout_mode_uses_clipboard_adapter
      with_notes do |dir|
        write_note(dir, 'Ideas/Game.md', "#ctx/current\nClipboard note")
        stdout = StringIO.new
        stderr = StringIO.new
        clipboard = FakeClipboard.new

        code = chdir(dir) do
          CLI.new(
            ['--query', 'tag:#ctx/current', '--all'],
            io: { stdout:, stderr: },
            dependencies: { clipboard: }
          ).run
        end

        assert_equal 0, code
        assert_empty stderr.string
        assert_equal 1, clipboard.copied_payloads.length
        assert_includes clipboard.copied_payloads.first, '# Context Bundle'
      end
    end

    def test_clipboard_failure_surfaces_stdout_fallback_tip
      with_notes do |dir|
        write_note(dir, 'Ideas/Game.md', "#ctx/current\nClipboard note")
        stdout = StringIO.new
        stderr = StringIO.new
        clipboard = FailingClipboard.new

        code = chdir(dir) do
          CLI.new(
            ['--query', 'tag:#ctx/current', '--all'],
            io: { stdout:, stderr: },
            dependencies: { clipboard: }
          ).run
        end

        assert_equal 1, code
        assert_empty stdout.string
        assert_includes stderr.string, 'No supported clipboard command found'
        assert_includes stderr.string, 'rerun with --stdout'
      end
    end

    def test_version_flag_prints_current_version
      stdout = StringIO.new
      stderr = StringIO.new

      assert_raises(SystemExit) do
        CLI.new(['--version'], io: { stdout:, stderr: }).run
      end

      assert_equal "#{Architext::VERSION}\n", stdout.string
      assert_empty stderr.string
    end

    def test_set_default_vault_flag_persists_value_and_exits
      Dir.mktmpdir do |dir|
        stdout = StringIO.new
        stderr = StringIO.new
        settings = Settings.new(config_path: File.join(dir, 'default_vault'))

        code = CLI.new(
          ['--set-default-vault', 'Main Vault'],
          io: { stdout:, stderr: },
          dependencies: { settings: }
        ).run

        assert_equal 0, code
        assert_equal "Default vault set to: Main Vault\n", stdout.string
        assert_empty stderr.string
        assert_equal 'Main Vault', settings.default_vault
      end
    end

    def test_clear_default_vault_flag_clears_value_and_exits
      Dir.mktmpdir do |dir|
        stdout = StringIO.new
        stderr = StringIO.new
        path = File.join(dir, 'default_vault')
        settings = Settings.new(config_path: path)
        settings.default_vault = 'Main Vault'

        code = CLI.new(
          ['--clear-default-vault'],
          io: { stdout:, stderr: },
          dependencies: { settings: }
        ).run

        assert_equal 0, code
        assert_equal "Default vault cleared.\n", stdout.string
        assert_empty stderr.string
        assert_nil settings.default_vault
      end
    end

    def test_saved_default_vault_is_used_in_obsidian_mode_when_vault_flag_is_omitted
      Dir.mktmpdir do |dir|
        stdout = StringIO.new
        stderr = StringIO.new
        settings = Settings.new(config_path: File.join(dir, 'default_vault'))
        settings.default_vault = 'Main Vault'

        with_fake_obsidian(search_paths: []) do |obsidian_path|
          code = with_env('ARCHITEXT_OBSIDIAN' => obsidian_path) do
            CLI.new(
              ['--source', 'obsidian', '--query', 'tag:#missing', '--all', '--stdout'],
              io: { stdout:, stderr: },
              dependencies: { settings: },
              app_name: 'architext'
            ).run
          end

          assert_equal 1, code
          assert_includes stderr.string, 'Main Vault'
          assert_includes stderr.string, '(saved default)'
        end
      end
    end

    def test_prefers_text_search_when_json_output_is_empty
      with_fake_obsidian(search_paths: ['Ideas/Game.md'], search_mode: :text_only) do |obsidian_path|
        stdout = StringIO.new
        stderr = StringIO.new

        code = with_env('ARCHITEXT_OBSIDIAN' => obsidian_path) do
          CLI.new(
            ['--source', 'obsidian', '--query', 'game', '--all', '--stdout'],
            io: { stdout:, stderr: }
          ).run
        end

        assert_equal 0, code
        assert_empty stderr.string
        assert_includes stdout.string, 'Ideas/Game.md'
      end
    end

    def test_diagnose_prints_native_connection_details
      with_notes do |dir|
        write_note(dir, 'Ideas/Game.md', 'Diagnostic note')
        stdout = StringIO.new
        stderr = StringIO.new

        code = CLI.new(['--root', dir, '--diagnose'], io: { stdout:, stderr: }).run

        assert_equal 0, code
        assert_empty stderr.string
        assert_includes stdout.string, 'ARCHiTEXT diagnostics'
        assert_includes stdout.string, 'active source: native'
        assert_includes stdout.string, "root path: #{File.realpath(dir)}"
        assert_includes stdout.string, 'markdown files: 1'
        refute_includes stdout.string, 'obsidian cli executable'
      end
    end

    def test_diagnose_prints_obsidian_connection_details
      with_fake_obsidian do |obsidian_path|
        stdout = StringIO.new
        stderr = StringIO.new

        code = with_env('ARCHITEXT_OBSIDIAN' => obsidian_path) do
          CLI.new(['--source', 'obsidian', '--diagnose'], io: { stdout:, stderr: }).run
        end

        assert_equal 0, code
        assert_empty stderr.string
        assert_includes stdout.string, 'ARCHiTEXT diagnostics'
        assert_includes stdout.string, 'active source: obsidian'
        assert_includes stdout.string, 'connection check: ok'
        assert_includes stdout.string, 'resolved vault: Main Vault | /vaults/main'
      end
    end

    private

    class FakeClipboard
      attr_reader :copied_payloads

      def initialize
        @copied_payloads = []
      end

      def copy(text)
        @copied_payloads << text
      end
    end

    class FailingClipboard
      def copy(_text)
        raise Clipboard::UnsupportedPlatform, 'No supported clipboard command found.'
      end
    end

    def with_fake_obsidian(search_paths: ['Ideas/Game.md', 'Plans/Roadmap.md'], search_mode: :normal)
      Dir.mktmpdir do |dir|
        obsidian_path = build_fake_obsidian_executable(dir, search_paths, search_mode)
        yield obsidian_path
      end
    end

    def build_fake_obsidian_executable(dir, search_paths, search_mode)
      if Gem.win_platform?
        script_path = File.join(dir, 'obsidian.rb')
        launcher_path = File.join(dir, 'obsidian.cmd')
        File.write(script_path, fake_obsidian_script(search_paths, search_mode))
        File.write(launcher_path, "@echo off\r\nruby \"%~dp0obsidian.rb\" %*\r\n")
        launcher_path
      else
        path = File.join(dir, 'obsidian')
        File.write(path, fake_obsidian_script(search_paths, search_mode))
        FileUtils.chmod('+x', path)
        path
      end
    end

    def fake_obsidian_script(search_paths, search_mode)
      <<~RUBY
        #!/usr/bin/env ruby
        # frozen_string_literal: true

        require "json"

        command = ARGV.find { |arg| %w[search read].include?(arg) }
        command ||= ARGV.find { |arg| %w[version vault].include?(arg) }

        case command
        when "version"
          puts "1.12.7"
        when "vault"
          puts "name Main Vault"
          puts "path /vaults/main"
        when "search"
          format = ARGV.find { |arg| arg.start_with?("format=") }.to_s.split("=", 2).last
          mode = #{search_mode.to_s.inspect}
          paths = JSON.parse(#{JSON.dump(search_paths).inspect})
          if mode == "text_only" && format == "json"
            puts "[]"
          elsif format == "text"
            puts paths.join("\\n")
          else
            puts JSON.dump(paths)
          end
        when "read"
          path = ARGV.find { |arg| arg.start_with?("path=") }.split("=", 2).last
          if path == "bad.md"
            warn "cannot read " + path
            exit 2
          end

          puts "Contents for " + path
        else
          warn "unknown command"
          exit 1
        end
      RUBY
    end

    def with_notes(&)
      Dir.mktmpdir(&)
    end

    def write_note(root, path, content)
      full_path = File.join(root, path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
    end

    def chdir(path)
      previous = Dir.pwd
      Dir.chdir(path)
      yield
    ensure
      Dir.chdir(previous)
    end

    def with_env(values)
      old_values = values.to_h { |key, _value| [key, ENV.fetch(key, nil)] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      old_values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end
  end
  # rubocop:enable Metrics/ClassLength

  class ClipboardTest < Minitest::Test
    FakeStatus = Struct.new(:successful, :exitstatus) do
      def success?
        successful
      end
    end

    def test_windows_uses_clip_when_available
      Dir.mktmpdir do |dir|
        captured = nil
        runner = lambda do |*args, stdin_data:|
          raise Errno::ENOENT, args.first unless args.first == 'clip'

          captured = [args, stdin_data]
          ['', '', FakeStatus.new(true, 0)]
        end

        clipboard = Clipboard.new(
          runner:,
          env: { 'PATH' => dir, 'PATHEXT' => '.EXE;.CMD' },
          host_os: 'x64-mingw-ucrt'
        )

        clipboard.copy('hello')

        assert_equal ['clip'], captured.first
        assert_equal 'hello', captured.last
      end
    end

    def test_linux_falls_back_to_xclip_when_wl_copy_is_missing
      Dir.mktmpdir do |dir|
        captured = nil
        runner = lambda do |*args, stdin_data:|
          raise Errno::ENOENT, args.first unless args.first == 'xclip'

          captured = [args, stdin_data]
          ['', '', FakeStatus.new(true, 0)]
        end

        clipboard = Clipboard.new(
          runner:,
          env: { 'PATH' => dir },
          host_os: 'linux-gnu'
        )

        clipboard.copy('payload')

        assert_equal ['xclip', '-selection', 'clipboard'], captured.first
        assert_equal 'payload', captured.last
      end
    end

    def test_raises_when_no_clipboard_command_is_available
      clipboard = Clipboard.new(
        runner: lambda { |*args, stdin_data:|
          _ = stdin_data
          raise Errno::ENOENT, args.first
        },
        env: { 'PATH' => '' },
        host_os: 'linux-gnu'
      )

      error = assert_raises(Clipboard::UnsupportedPlatform) { clipboard.copy('x') }
      assert_includes error.message, 'No supported clipboard command found'
    end
  end
end
