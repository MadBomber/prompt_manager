# frozen_string_literal: true

require_relative 'test_helper'

# A test directive subclass used only by these tests.
# Defined at top level so method_added fires during class body evaluation.
class PMTestDirectives < PM::Directive
  desc "Say hello"
  def greet(ctx, name)
    "Hello, #{name}!"
  end
  alias_method :hi, :greet

  desc "Upcase text"
  def echo_back(ctx, text)
    text.upcase
  end

  # No desc → not a directive
  def helper_method
    "I am a helper"
  end
end

class PMDirectiveDescTest < Minitest::Test
  def teardown
    PM.reset_directives!
  end

  def test_desc_captures_description
    assert_equal "Say hello", PMTestDirectives.directive_descriptions[:greet]
  end

  def test_desc_captures_multiple_descriptions
    assert_equal "Upcase text", PMTestDirectives.directive_descriptions[:echo_back]
  end

  def test_method_without_desc_not_captured
    refute PMTestDirectives.directive_descriptions.key?(:helper_method)
  end

  def test_alias_detected
    aliases = PMTestDirectives.directive_aliases[:greet]
    assert_includes aliases, :hi
  end

  def test_no_alias_for_non_aliased_method
    assert_nil PMTestDirectives.directive_aliases[:echo_back]
  end
end

class PMDirectiveSubclassTrackingTest < Minitest::Test
  def test_subclasses_tracked_centrally
    assert_includes PM::Directive.directive_subclasses, PM::CoreDirectives
    assert_includes PM::Directive.directive_subclasses, PMTestDirectives
  end

  def test_directive_subclasses_accessible_from_subclass
    # Calling directive_subclasses on a subclass returns the same list
    subs = PMTestDirectives.directive_subclasses
    assert_includes subs, PM::CoreDirectives
    assert_includes subs, PMTestDirectives
  end
end

class PMDirectiveCategoryNameTest < Minitest::Test
  def test_core_directives_category_name
    assert_equal "Core", PM::CoreDirectives.category_name
  end

  def test_test_directives_category_name
    assert_equal "PMTest", PMTestDirectives.category_name
  end
end

class PMDirectiveRegisterAllTest < Minitest::Test
  def teardown
    PM.reset_directives!
  end

  def test_register_all_registers_core_directives
    PM.reset_directives!

    assert PM.directives.key?(:include)
    assert PM.directives.key?(:insert)
    assert PM.directives.key?(:read)
  end

  def test_register_all_registers_test_directives
    PM.reset_directives!

    assert PM.directives.key?(:greet)
    assert PM.directives.key?(:hi)
    assert PM.directives.key?(:echo_back)
  end

  def test_register_all_skips_non_directive_methods
    PM.reset_directives!

    refute PM.directives.key?(:helper_method)
  end

  def test_registered_directive_callable
    PM.reset_directives!

    block = PM.directives[:greet]
    result = block.call(nil, "Alice")
    assert_equal "Hello, Alice!", result
  end

  def test_registered_alias_callable
    PM.reset_directives!

    block = PM.directives[:hi]
    result = block.call(nil, "Bob")
    assert_equal "Hello, Bob!", result
  end

  def test_register_all_creates_instance
    PM.reset_directives!

    assert_instance_of PMTestDirectives, PMTestDirectives.instance
  end

  def test_register_all_idempotent
    PM.reset_directives!
    PM.reset_directives!

    assert PM.directives.key?(:include)
    assert PM.directives.key?(:greet)
  end
end

class PMDirectiveBuildDispatchBlockTest < Minitest::Test
  def test_default_dispatch_passes_ctx_and_args
    inst = PMTestDirectives.new
    block = PMTestDirectives.build_dispatch_block(inst, :greet)

    result = block.call(nil, "World")
    assert_equal "Hello, World!", result
  end
end

class PMCoreDirectivesTest < Minitest::Test
  def test_core_directives_has_include
    assert PM::CoreDirectives.directive_descriptions.key?(:include)
  end

  def test_core_directives_has_insert
    assert PM::CoreDirectives.directive_descriptions.key?(:insert)
  end

  def test_core_directives_has_read_alias
    aliases = PM::CoreDirectives.directive_aliases[:insert]
    assert_includes aliases, :read
  end

  def test_insert_and_read_share_same_block
    assert_same PM.directives[:insert], PM.directives[:read]
  end
end
