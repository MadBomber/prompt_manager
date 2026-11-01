# frozen_string_literal: true

require_relative 'test_helper'

class PMRegistryPolicyTest < Minitest::Test
  def teardown
    @extra_classes&.each { |klass| PM::Directive.directive_subclasses.delete(klass) }
    PM.reset_directives!
  end

  def test_directives_snapshot_is_frozen
    assert_predicate PM.directives, :frozen?
  end

  def test_mutating_a_snapshot_does_not_affect_the_registry
    snapshot = PM.directives.dup
    snapshot.delete(:include)

    assert PM.directive?(:include)
    assert PM.directives.key?(:include)
  end

  def test_directive_predicate_accepts_strings_and_symbols
    assert PM.directive?('include')
    assert PM.directive?(:read)
    refute PM.directive?(:nope)
  end

  def test_register_without_block_raises
    assert_raises(ArgumentError) { PM.register(:no_block) }
  end

  def test_register_all_raises_when_name_is_held_by_a_block_directive
    PM.register(:probe_block) { |_ctx| 'block' }
    define_directive_class('ProbeBlockDirectives', :probe_block, 'class')

    error = assert_raises(PM::DirectiveAlreadyRegisteredError) { PM::Directive.register_all }

    assert_includes error.message, 'probe_block'
    assert_includes error.message, 'PM.register'
  end

  def test_later_subclass_overrides_earlier_one
    define_directive_class('FirstDirectives',  :dup_name, 'first')
    define_directive_class('SecondDirectives', :dup_name, 'second')
    PM::Directive.register_all

    assert_equal 'second', PM.parse_string('<%= dup_name %>').to_s
  end

  def test_register_all_is_idempotent
    define_directive_class('IdemDirectives', :idem, 'ok')
    PM::Directive.register_all
    PM::Directive.register_all

    assert_equal 'ok', PM.parse_string('<%= idem %>').to_s
  end

  def test_block_directive_cannot_take_a_class_owned_name
    error = assert_raises(PM::DirectiveAlreadyRegisteredError) { PM.register(:insert) { |_ctx| 'x' } }

    assert_includes error.message, 'insert'
  end

  def test_error_hierarchy
    assert_operator PM::DirectiveAlreadyRegisteredError, :<, PM::Error
  end

  def test_register_all_skips_subclasses_without_described_methods
    klass = Class.new(PM::Directive) do
      define_singleton_method(:name) { 'HelperOnlyDirectives' }
      define_method(:helper) { |_ctx| 'never registered' }
    end
    (@extra_classes ||= []) << klass

    PM::Directive.register_all

    refute PM.directive?(:helper)
    assert_nil klass.instance
  end

  private

  def define_directive_class(class_name, directive_name, return_value)
    klass = Class.new(PM::Directive) do
      define_singleton_method(:name) { class_name }
      desc "returns #{return_value}"
      define_method(directive_name) { |_ctx| return_value }
    end
    (@extra_classes ||= []) << klass
    klass
  end
end
