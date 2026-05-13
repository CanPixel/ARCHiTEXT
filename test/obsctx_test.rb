# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'stringio'
require 'tmpdir'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'obsctx/bundle'
require 'obsctx/cli'
require 'obsctx/search_results'
require 'obsctx/selection_parser'
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
          CLI.new(['--query', 'tag:#ctx/current', '--all', '--stdout'], stdout:, stderr:).run
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
          CLI.new(['--query', 'tag:#ctx/current', '--all', '--stdout'], stdout:, stderr:).run
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
          CLI.new(['--query', 'tag:#missing', '--all', '--stdout'], stdout:, stderr:, app_name: 'architext').run
        end

        assert_equal 1, code
        assert_empty stdout.string
        assert_includes stderr.string, 'No Obsidian notes matched'
        refute_includes stderr.string, 'No files selected'
      end
    end

    private

    def with_fake_obsidian(search_paths: ['Ideas/Game.md', 'Plans/Roadmap.md'])
      Dir.mktmpdir do |dir|
        obsidian_path = File.join(dir, 'obsidian')
        File.write(obsidian_path, fake_obsidian_script(search_paths))
        FileUtils.chmod('+x', obsidian_path)
        yield obsidian_path
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
end
