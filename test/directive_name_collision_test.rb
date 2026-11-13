# frozen_string_literal: true

require_relative 'test_helper'

# A directive named like an Object or Kernel method (`format`, `test`, `exec`)
# must be reachable from a template, the same as any other directive.
class PMDirectiveNameCollisionTest < Minitest::Test
  def teardown
    PM.config.reset!
    PM.reset_directives!
  end

  def test_directive_named_format_is_called_with_arguments
    PM.register(:format) { |_ctx, x| "D(#{x})" }

    assert_equal 'D(x)', PM.parse_string('<%= format("x") %>').to_s
  end

  def test_directive_named_test_is_called_with_arguments
    PM.register(:test) { |_ctx, x| "D(#{x})" }

    assert_equal 'D(x)', PM.parse_string('<%= test("x") %>').to_s
  end

  def test_directive_named_like_kernel_method_is_called_bare
    PM.register(:format) { |_ctx| 'D' }

    assert_equal 'D', PM.parse_string('<%= format %>').to_s
  end

  def test_directive_receives_keyword_arguments_and_block
    PM.register(:format) { |_ctx, opts, &blk| "#{opts[:a]}#{blk.call}" }

    assert_equal '1b', PM.parse_string('<%= format(a: 1) { "b" } %>').to_s
  end

  def test_parameter_wins_bare_and_directive_wins_with_arguments
    PM.register(:format) { |_ctx, x| "D(#{x})" }

    src = "---\nparameters:\n  format: P\n---\n<%= format %> <%= format('y') %>"

    assert_equal 'P D(y)', PM.parse_string(src).to_s
  end

  def test_kernel_method_still_used_when_no_directive_has_its_name
    src = "---\nparameters:\n  format: P\n---\n<%= format %> <%= format('%02d', 7) %>"

    assert_equal 'P 07', PM.parse_string(src).to_s
  end

  def test_directive_wins_over_parameter_when_called_with_only_a_block
    PM.register(:format) { |_ctx, &blk| "D(#{blk.call})" }

    src = "---\nparameters:\n  format: P\n---\n<%= format { 'b' } %>"

    assert_equal 'D(b)', PM.parse_string(src).to_s
  end

  def test_directive_named_raise_does_not_swallow_strict_errors
    PM.config.strict_parameters = true
    PM.register(:raise) { |_ctx, *_args| 'X' }

    assert_raises(PM::UnknownParameterError) { PM.parse_string('<%= nmae %>').to_s }
  end

  def test_directive_named_like_a_singleton_hook_is_not_called_while_shadowing
    calls = []
    PM.register(:singleton_method_added) { |_ctx, *args| calls << args }
    PM.register(:format) { |_ctx, x| "D(#{x})" }

    assert_equal "D(x)", PM.parse_string(%q(<%= format("x") %>)).to_s
    assert_empty calls
  end

  def test_directive_named_define_singleton_method_does_not_block_other_shadows
    PM.register(:define_singleton_method) { |_ctx| 'X' }
    PM.register(:test) { |_ctx, x| "D(#{x})" }

    assert_equal 'D(x)', PM.parse_string('<%= test("x") %>').to_s
  end

  def test_resolve_shadowed_in_isolation
    scope = PM::RenderScope.new({ 'format' => 'P' }, { test: ->(ctx, x) { "#{ctx}:#{x}" } }, 'C')

    assert_equal 'P', scope.send(:resolve_shadowed, :format, [], {}, nil)
    assert_equal '07', scope.send(:resolve_shadowed, :format, ['%02d', 7], {}, nil)
    assert_equal 'C:x', scope.send(:resolve_shadowed, :test, ['x'], {}, nil)
  end

  def test_directive_named_exec_resolves_to_the_directive
    PM.register(:exec) { |_ctx, x| "D(#{x})" }
    scope = PM::RenderScope.new({}, PM.directives, nil)

    assert_equal scope.singleton_class, scope.method(:exec).owner
  end

  def test_unregistered_kernel_names_are_left_alone
    scope = PM::RenderScope.new({}, PM.directives, nil)

    assert_equal Kernel, scope.method(:exec).owner
    assert_equal Kernel, scope.method(:sprintf).owner
  end
end
