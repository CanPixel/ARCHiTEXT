# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'stringio'
require 'tmpdir'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'obsctx/bundle'
require 'obsctx/clipboard'
require 'obsctx/cli'
require 'obsctx/search_results'
require 'obsctx/selection_parser'
require 'obsctx/settings'
require 'obsctx/terminal'

module ObsidianContext
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
  end

  class CLITest < Minitest::Test
    def test_stdout_all_uses_obsidian_search_and_read
      with_fake_obsidian do |obsidian_path|
        stdout = StringIO.new
        stderr = StringIO.new

        code = with_env('OBSCTX_OBSIDIAN' => obsidian_path) do
          CLI.new(
            ['--query', 'tag:#ctx/current', '--all', '--stdout'],
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

    def test_read_failure_returns_error
      with_fake_obsidian(search_paths: ['Ideas/Game.md', 'bad.md']) do |obsidian_path|
        stdout = StringIO.new
        stderr = StringIO.new

        code = with_env('OBSCTX_OBSIDIAN' => obsidian_path) do
          CLI.new(
            ['--query', 'tag:#ctx/current', '--all', '--stdout'],
            io: { stdout:, stderr: }
          ).run
        end

        assert_equal 1, code
        assert_empty stdout.string
        assert_includes stderr.string, 'Obsidian command failed'
      end
    end

    def test_no_results_returns_error_without_extra_no_selection_message
      with_fake_obsidian(search_paths: []) do |obsidian_path|
        stdout = StringIO.new
        stderr = StringIO.new

        code = with_env('OBSCTX_OBSIDIAN' => obsidian_path) do
          CLI.new(
            ['--query', 'tag:#missing', '--all', '--stdout'],
            io: { stdout:, stderr: },
            app_name: 'architext'
          ).run
        end

        assert_equal 1, code
        assert_empty stdout.string
        assert_includes stderr.string, 'No Obsidian notes matched'
        refute_includes stderr.string, 'No files selected'
      end
    end

    def test_non_stdout_mode_uses_clipboard_adapter
      with_fake_obsidian do |obsidian_path|
        stdout = StringIO.new
        stderr = StringIO.new
        clipboard = FakeClipboard.new

        code = with_env('OBSCTX_OBSIDIAN' => obsidian_path) do
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
      with_fake_obsidian do |obsidian_path|
        stdout = StringIO.new
        stderr = StringIO.new
        clipboard = FailingClipboard.new

        code = with_env('OBSCTX_OBSIDIAN' => obsidian_path) do
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

      assert_equal "#{ObsidianContext::VERSION}\n", stdout.string
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

    def test_saved_default_vault_is_used_when_vault_flag_is_omitted
      Dir.mktmpdir do |dir|
        stdout = StringIO.new
        stderr = StringIO.new
        settings = Settings.new(config_path: File.join(dir, 'default_vault'))
        settings.default_vault = 'Main Vault'

        with_fake_obsidian(search_paths: []) do |obsidian_path|
          code = with_env('OBSCTX_OBSIDIAN' => obsidian_path) do
            CLI.new(
              ['--query', 'tag:#missing', '--all', '--stdout'],
              io: { stdout:, stderr: },
              dependencies: { settings: },
              app_name: 'architext'
            ).run
          end

          assert_equal 1, code
          assert_includes stderr.string, 'active vault:'
          assert_includes stderr.string, 'Main Vault'
        end
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

    def with_fake_obsidian(search_paths: ['Ideas/Game.md', 'Plans/Roadmap.md'])
      Dir.mktmpdir do |dir|
        obsidian_path = build_fake_obsidian_executable(dir, search_paths)
        yield obsidian_path
      end
    end

    def build_fake_obsidian_executable(dir, search_paths)
      if Gem.win_platform?
        script_path = File.join(dir, 'obsidian.rb')
        launcher_path = File.join(dir, 'obsidian.cmd')
        File.write(script_path, fake_obsidian_script(search_paths))
        File.write(launcher_path, "@echo off\r\nruby \"%~dp0obsidian.rb\" %*\r\n")
        launcher_path
      else
        path = File.join(dir, 'obsidian')
        File.write(path, fake_obsidian_script(search_paths))
        FileUtils.chmod('+x', path)
        path
      end
    end

    def fake_obsidian_script(search_paths)
      <<~RUBY
        #!/usr/bin/env ruby
        # frozen_string_literal: true

        require "json"

        command = ARGV.find { |arg| %w[search read].include?(arg) }

        case command
        when "search"
          puts #{JSON.dump(search_paths).inspect}
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

    def with_env(values)
      old_values = values.to_h { |key, _value| [key, ENV.fetch(key, nil)] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      old_values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end
  end

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
