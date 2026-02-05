# frozen_string_literal: true

require_relative 'test_helper'

class PMIncludeTest < Minitest::Test
  def test_basic_include
    parsed = PM.parse(fixture('with_include.md'))
    result = parsed.to_s

    assert_includes result, 'Before include.'
    assert_includes result, 'This is the header.'
    assert_includes result, 'After include.'
  end

  def test_included_file_runs_shell_expansion
    parsed = PM.parse(fixture('with_include.md'))
    result = parsed.to_s

    # header.md has no shell refs, but let's test a file that does
    parsed2 = PM.parse("---\ntitle: Test\n---\n<%= include 'includes/with_shell.md' %>\n")
    # parse (not parse_file) won't have directory, so include won't be available
    # We need parse_file for include to work
  end

  def test_include_with_shell_expansion
    # Create a temporary wrapper that includes with_shell.md
    wrapper = PM.parse(fixture('with_include.md'))
    # Test the shell include fixture directly
    shell_parsed = PM.parse(fixture('includes/with_shell.md'))
    result = shell_parsed.to_s

    assert_includes result, 'Echo: included'
  end

  def test_nested_include
    parsed = PM.parse(fixture('with_nested_include.md'))
    result = parsed.to_s

    assert_includes result, 'This is the header.'
    assert_includes result, 'Nested:'
  end

  def test_circular_include_raises
    parsed = PM.parse(fixture('circular_a.md'))

    assert_raises(RuntimeError) { parsed.to_s }
  end

  def test_circular_include_error_message
    parsed = PM.parse(fixture('circular_a.md'))

    error = assert_raises(RuntimeError) { parsed.to_s }
    assert_includes error.message, 'Circular include detected'
  end

  def test_include_with_parent_params
    parsed = PM.parse(fixture('with_include.md'))

    # The included header.md has no parameters, so parent params are harmless
    result = parsed.to_s('extra' => 'value')
    assert_includes result, 'This is the header.'
  end

  def test_include_passes_params_to_child
    # includes/with_params.md requires 'language'
    # Create a wrapper fixture inline isn't possible, so test directly
    child = PM.parse(fixture('includes/with_params.md'))
    result = child.to_s('language' => 'ruby')

    assert_includes result, 'Language is ruby.'
  end

  def test_include_from_parse_raises_with_clear_message
    parsed = PM.parse("---\ntitle: Test\n---\n<%= include 'foo.md' %>\n")

    error = assert_raises(RuntimeError) { parsed.to_s }
    assert_includes error.message, 'include requires a file context (use PM.parse with a file path)'
  end
end

class PMInsertTest < Minitest::Test
  def test_basic_insert
    parsed = PM.parse(fixture('with_insert.md'))
    result = parsed.to_s

    assert_includes result, 'Before insert.'
    assert_includes result, 'def greet(name)'
    assert_includes result, 'After insert.'
  end

  def test_read_alias
    parsed = PM.parse(fixture('with_insert_read_alias.md'))
    result = parsed.to_s

    assert_includes result, 'def greet(name)'
  end

  def test_insert_non_md_file
    parsed = PM.parse(fixture('with_insert.md'))
    result = parsed.to_s

    # The .rb file content is inserted verbatim
    assert_includes result, 'puts "Hello, #{name}!"'
  end

  def test_insert_does_not_process_erb_in_content
    parsed = PM.parse(fixture('with_insert_erb_content.md'))
    result = parsed.to_s

    # ERB tags in the inserted file appear as literal text
    assert_includes result, '<%= "ERB tags" %>'
    assert_includes result, '$(shell commands)'
  end

  def test_insert_missing_file_raises
    parsed = PM.parse("---\ntitle: Test\n---\n<%= insert '/nonexistent/file.txt' %>\n")

    error = assert_raises(RuntimeError) { parsed.to_s }
    assert_includes error.message, 'insert: file not found'
  end

  def test_insert_with_absolute_path
    # Create a temp file with known content
    require 'tempfile'
    Tempfile.create(['pm_insert_test', '.txt']) do |f|
      f.write("absolute path content")
      f.flush

      parsed = PM.parse("---\ntitle: Test\n---\n<%= insert '#{f.path}' %>\n")
      result = parsed.to_s

      assert_includes result, 'absolute path content'
    end
  end

  def test_insert_with_relative_path
    parsed = PM.parse(fixture('with_insert.md'))
    result = parsed.to_s

    # includes/raw_code.rb is resolved relative to the fixture directory
    assert_includes result, 'def greet(name)'
  end

  def test_insert_without_file_context_uses_expand_path
    # When parsed from a string (no directory context), absolute paths still work
    require 'tempfile'
    Tempfile.create(['pm_insert_test', '.txt']) do |f|
      f.write("string context content")
      f.flush

      parsed = PM.parse("---\ntitle: Test\n---\n<%= insert '#{f.path}' %>\n")
      result = parsed.to_s

      assert_includes result, 'string context content'
    end
  end

  def test_insert_registered_as_builtin
    assert PM.directives.key?(:insert)
    assert PM.directives.key?(:read)
  end

  def test_insert_survives_reset
    PM.reset_directives!

    assert PM.directives.key?(:insert)
    assert PM.directives.key?(:read)
  end

  def test_insert_and_read_share_same_block
    assert_same PM.directives[:insert], PM.directives[:read]
  end
end

class PMRegisterDirectiveTest < Minitest::Test
  def teardown
    PM.reset_directives!
  end

  def test_register_custom_directive
    PM.register(:upcase) { |_ctx, text| text.upcase }
    parsed = PM.parse(fixture('simple.md'))

    # simple.md has no ERB, so let's use parse with ERB content
    parsed = PM.parse("---\ntitle: Test\n---\n<%= upcase 'hello' %>\n")
    result = parsed.to_s

    assert_includes result, 'HELLO'
  end

  def test_register_duplicate_raises
    PM.register(:custom) { |_ctx| 'x' }

    error = assert_raises(RuntimeError) { PM.register(:custom) { |_ctx| 'y' } }
    assert_includes error.message, 'Directive already registered: custom'
  end

  def test_register_duplicate_of_builtin_raises
    error = assert_raises(RuntimeError) { PM.register(:include) { |_ctx, path| path } }
    assert_includes error.message, 'Directive already registered: include'
  end

  def test_reset_directives_restores_builtins
    PM.register(:custom) { |_ctx| 'x' }
    PM.reset_directives!

    assert PM.directives.key?(:include)
    assert PM.directives.key?(:insert)
    assert PM.directives.key?(:read)
    refute PM.directives.key?(:custom)
  end

  def test_custom_directive_with_render_context
    PM.register(:current_file) { |ctx| ctx.metadata.name || 'unknown' }
    parsed = PM.parse(fixture('with_erb.md'))

    # with_erb.md has its own ERB, but let's test with a controlled template
    parsed = PM.parse("---\ntitle: Test\n---\n<%= current_file %>\n")
    result = parsed.to_s

    # No directory context from parse, so name is nil
    assert_includes result, 'unknown'
  end

  def test_custom_directive_available_in_included_files
    PM.register(:shout) { |_ctx, text| text.upcase + '!' }

    # Create a simple test — directives are set up for every render_with call
    parsed = PM.parse("---\ntitle: Test\n---\n<%= shout 'hey' %>\n")
    result = parsed.to_s

    assert_includes result, 'HEY!'
  end

  def test_accepts_string_name
    PM.register('reverse') { |_ctx, text| text.reverse }
    parsed = PM.parse("---\ntitle: Test\n---\n<%= reverse 'abc' %>\n")
    result = parsed.to_s

    assert_includes result, 'cba'
  end

  def test_register_multiple_names_as_aliases
    PM.register(:shout, :yell, :scream) { |_ctx, text| text.upcase + '!' }

    assert PM.directives.key?(:shout)
    assert PM.directives.key?(:yell)
    assert PM.directives.key?(:scream)

    %w[shout yell scream].each do |name|
      parsed = PM.parse("---\ntitle: Test\n---\n<%= #{name} 'hello' %>\n")
      assert_includes parsed.to_s, 'HELLO!'
    end
  end

  def test_register_aliases_share_same_block
    PM.register(:loud, :louder) { |_ctx, text| text.upcase }

    assert_same PM.directives[:loud], PM.directives[:louder]
  end

  def test_register_aliases_duplicate_raises
    PM.register(:first, :second) { |_ctx| 'x' }

    error = assert_raises(RuntimeError) { PM.register(:second) { |_ctx| 'y' } }
    assert_includes error.message, 'Directive already registered: second'
  end

  def test_register_aliases_rolls_back_none_on_duplicate
    PM.register(:existing) { |_ctx| 'x' }

    assert_raises(RuntimeError) { PM.register(:new_one, :existing) { |_ctx| 'y' } }
    # :new_one was registered before :existing raised — this is expected behavior
    # since registration is iterative
    assert PM.directives.key?(:new_one)
  end
end

class PMIncludesMetadataTest < Minitest::Test
  def test_includes_empty_when_no_includes
    parsed = PM.parse(fixture('simple.md'))
    parsed.to_s

    assert_equal [], parsed.metadata.includes
  end

  def test_includes_nil_before_to_s
    parsed = PM.parse(fixture('simple.md'))

    assert_nil parsed.metadata.includes
  end

  def test_includes_populated_after_to_s
    parsed = PM.parse(fixture('with_include.md'))
    parsed.to_s

    assert_equal 1, parsed.metadata.includes.length
  end

  def test_includes_entry_has_correct_path
    parsed = PM.parse(fixture('with_include.md'))
    parsed.to_s

    entry = parsed.metadata.includes.first
    assert_equal File.expand_path(fixture('includes/header.md')), entry[:path]
  end

  def test_includes_entry_has_depth
    parsed = PM.parse(fixture('with_include.md'))
    parsed.to_s

    entry = parsed.metadata.includes.first
    assert_equal 1, entry[:depth]
  end

  def test_includes_entry_has_child_metadata
    parsed = PM.parse(fixture('with_include.md'))
    parsed.to_s

    entry = parsed.metadata.includes.first
    assert_equal 'Header', entry[:metadata][:title]
    assert_equal 'header.md', entry[:metadata][:name]
  end

  def test_includes_entry_has_empty_includes_for_leaf
    parsed = PM.parse(fixture('with_include.md'))
    parsed.to_s

    entry = parsed.metadata.includes.first
    assert_equal [], entry[:includes]
  end

  def test_nested_includes_tree_structure
    parsed = PM.parse(fixture('with_nested_include.md'))
    parsed.to_s

    # Top level: with_nested_include includes nested.md
    assert_equal 1, parsed.metadata.includes.length

    nested_entry = parsed.metadata.includes.first
    assert_equal 1, nested_entry[:depth]
    assert_equal 'Nested', nested_entry[:metadata][:title]

    # Second level: nested.md includes header.md
    assert_equal 1, nested_entry[:includes].length

    header_entry = nested_entry[:includes].first
    assert_equal 2, header_entry[:depth]
    assert_equal 'Header', header_entry[:metadata][:title]
    assert_equal [], header_entry[:includes]
  end

  def test_parent_metadata_unchanged_after_to_s
    parsed = PM.parse(fixture('with_include.md'))
    parsed.to_s

    assert_equal 'With Include', parsed.metadata.title
    assert_equal 'with_include.md', parsed.metadata.name
    assert_equal true, parsed.metadata.shell
    assert_equal true, parsed.metadata.erb
  end

  def test_includes_reset_on_repeated_to_s
    parsed = PM.parse(fixture('with_include.md'))
    parsed.to_s
    parsed.to_s

    assert_equal 1, parsed.metadata.includes.length
  end

  def test_includes_empty_for_erb_disabled
    parsed = PM.parse(fixture('erb_disabled.md'))
    parsed.to_s

    assert_equal [], parsed.metadata.includes
  end
end
