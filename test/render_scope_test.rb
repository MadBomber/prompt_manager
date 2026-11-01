# frozen_string_literal: true

require_relative 'test_helper'

class PMRenderScopeTest < Minitest::Test
  def teardown
    PM.config.reset!
    PM.reset_directives!
  end

  def test_unknown_identifier_renders_empty_by_default
    assert_equal '[]', PM.parse_string('[<%= nmae %>]').to_s
  end

  def test_strict_mode_raises_for_unknown_identifier
    PM.config.strict_parameters = true

    error = assert_raises(PM::UnknownParameterError) { PM.parse_string('<%= nmae %>').to_s }

    assert_includes error.message, 'nmae'
    assert_kind_of ArgumentError, error
  end

  def test_strict_mode_allows_known_parameters_and_directives
    PM.config.strict_parameters = true
    PM.register(:shout) { |_ctx, text| text.upcase }

    assert_equal 'hi HI', PM.parse_string("---\nparameters:\n  w: hi\n---\n<%= w %> <%= shout 'hi' %>").to_s
  end

  def test_parameter_shadows_zero_argument_directive_of_same_name
    PM.register(:stamp) { |_ctx| 'directive' }

    assert_equal 'param', PM.parse_string("---\nparameters:\n  stamp: param\n---\n<%= stamp %>").to_s
  end

  def test_directive_call_with_arguments_wins_over_same_named_parameter
    PM.register(:stamp) { |_ctx, x| "d:#{x}" }

    assert_equal 'd:1', PM.parse_string("---\nparameters:\n  stamp: param\n---\n<%= stamp 1 %>").to_s
  end

  def test_unknown_call_with_arguments_raises_no_method_error
    assert_raises(NoMethodError) { PM.parse_string('<%= nope 1 %>').to_s }
  end

  def test_parameter_named_like_an_object_method_still_resolves
    source = "---\nparameters:\n  hash: h\n  display: d\n  method: m\n---\n<%= hash %>-<%= display %>-<%= method %>"

    assert_equal 'h-d-m', PM.parse_string(source).to_s
  end

  def test_directive_receives_a_block
    PM.register(:wrap) { |_ctx, tag, &block| "<#{tag}>#{block.call}</#{tag}>" }

    assert_equal '<b>x</b>', PM.parse_string("<%= wrap('b') { 'x' } %>").to_s
  end

  def test_scope_responds_to_parameters_and_directives
    scope = PM::RenderScope.new({ 'a' => 1 }, { b: proc {} }, PM::RenderContext.new)

    assert_respond_to scope, :a
    assert_respond_to scope, :b
    refute_respond_to scope, :c
  end

  def test_protected_object_methods_are_never_shadowed_by_parameters
    scope = PM::RenderScope.new({ 'class' => 'x', 'object_id' => 1 }, {}, PM::RenderContext.new)

    assert_equal PM::RenderScope, scope.class
    assert_kind_of Integer, scope.object_id
  end

end
