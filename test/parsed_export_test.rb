# frozen_string_literal: true

require_relative 'test_helper'

class PMParsedExportTest < Minitest::Test
  def teardown
    PM.config.reset!
  end

  def test_to_h_has_metadata_and_content
    parsed = PM.parse_string("---\ntitle: T\n---\nbody")

    assert_equal({ metadata: { title: 'T', shell: true, erb: true }, content: 'body' }, parsed.to_h)
  end

  def test_to_markdown_round_trips_authored_metadata
    source = "---\ntitle: T\nparameters:\n  name:\n---\nHello <%= name %>"
    again  = PM.parse_string(PM.parse_string(source).to_markdown)

    assert_equal 'T', again.metadata.title
    assert_equal({ 'name' => nil }, again.metadata.parameters)
    assert_equal 'Hello <%= name %>', again.content
  end

  def test_to_markdown_omits_file_derived_keys
    markdown = PM.parse(fixture('simple.md')).to_markdown

    refute_match(/^(directory|name|created_at|modified_at):/, markdown)
    assert_match(/^title:/, markdown)
  end

  def test_to_markdown_omits_includes_tree
    parsed = PM.parse(fixture('with_include.md'))
    parsed.to_s

    refute_includes parsed.to_markdown, 'includes:'
    assert_includes parsed.to_markdown, "<%= include 'includes/header.md' %>"
  end

  def test_to_markdown_always_writes_shell_and_erb
    markdown = PM.parse_string('no front matter').to_markdown

    assert_equal "---\nshell: true\nerb: true\n---\nno front matter", markdown
  end

  def test_to_markdown_content_is_post_shell_expansion
    markdown = PM.parse_string("---\ntitle: x\n---\n$(echo expanded)").to_markdown

    assert_includes markdown, 'expanded'
    refute_includes markdown, '$('
  end

  def test_parameters_helper
    assert_equal({ 'a' => 1 }, PM.parse_string("---\nparameters:\n  a: 1\n---\nx").parameters)
    assert_equal({}, PM.parse_string('x').parameters)
  end

  def test_key_predicate
    parsed = PM.parse_string("---\ntitle: T\n---\nx")

    assert parsed.key?('title')
    assert parsed.key?(:title)
    refute parsed.key?(:nope)
  end

  def test_parsed_is_an_immutable_data_object
    parsed = PM.parse_string('x')

    refute_respond_to parsed, :content=
    assert_equal 'y', parsed.with(content: 'y').content
    assert_equal 'x', parsed.content
  end

  def test_missing_parameter_error_class_and_message
    parsed = PM.parse_string("---\nparameters:\n  code:\n  lang:\n---\n<%= code %>")
    error  = assert_raises(PM::MissingParameterError) { parsed.to_s }

    assert_kind_of ArgumentError, error
    assert_kind_of PM::ParameterError, error
    assert_equal 'Missing required parameters: code, lang', error.message
  end

  def test_render_context_defaults
    ctx = PM::RenderContext.new

    assert_nil ctx.directory
    assert_equal({}, ctx.params)
    assert_equal Set.new, ctx.included
    assert_equal 0, ctx.depth
    assert_nil ctx.metadata
  end

  def test_render_context_is_immutable
    ctx = PM::RenderContext.new(depth: 2)

    refute_respond_to ctx, :depth=
    assert_equal 3, ctx.with(depth: 3).depth
  end

  def test_to_markdown_without_any_authored_metadata_is_just_the_content
    parsed = PM::Parsed.new(metadata: PM::Metadata.new, content: 'bare')

    assert_equal 'bare', parsed.to_markdown
  end

end
