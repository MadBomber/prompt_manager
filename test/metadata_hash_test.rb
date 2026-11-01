# frozen_string_literal: true

require_relative 'test_helper'

class PMMetadataHashTest < Minitest::Test
  def setup
    @meta = PM::Metadata.new('a' => 1, b: 2)
  end

  def test_string_and_symbol_keys_unify
    assert_equal 1, @meta[:a]
    assert_equal 2, @meta['b']
    assert_equal({ a: 1, b: 2 }, @meta.to_h)
  end

  def test_to_h_is_a_copy
    @meta.to_h[:zzz] = 1

    refute @meta.key?(:zzz)
  end

  def test_respond_to_for_present_keys_only
    assert_respond_to @meta, :a
    refute_respond_to @meta, :zzz
  end

  def test_unknown_key_returns_nil
    assert_nil @meta.zzz
  end

  def test_setter_via_dot_notation
    @meta.c = 3

    assert_equal 3, @meta[:c]
    assert_respond_to @meta, :c=
  end

  def test_bracket_setter_accepts_strings
    @meta['d'] = 4

    assert_equal 4, @meta.d
  end

  def test_predicate_only_for_booleans
    meta = PM::Metadata.new(flag: true, off: false, title: 'x')

    assert_equal true,  meta.flag?
    assert_equal false, meta.off?
    assert_respond_to meta, :flag?
    refute_respond_to meta, :title?
    assert_raises(NoMethodError) { meta.title? }
  end

  def test_bang_methods_are_never_keys
    refute_respond_to @meta, :a!
    assert_raises(NoMethodError) { @meta.a! }
  end

  def test_calls_with_arguments_raise
    assert_raises(NoMethodError) { @meta.a(1) }
  end

  def test_keys_named_like_object_methods_resolve_to_values
    meta = PM::Metadata.new(hash: 'h', display: 'd', method: 'm', name: 'n')

    assert_equal 'h', meta.hash
    assert_equal 'd', meta.display
    assert_equal 'm', meta.method
    assert_equal 'n', meta.name
  end

  def test_protected_methods_are_not_shadowed
    meta = PM::Metadata.new(class: 'x', to_h: 'y')

    assert_equal PM::Metadata, meta.class
    assert_equal({ class: 'x', to_h: 'y' }, meta.to_h)
    assert_equal 'x', meta[:class]
  end

  def test_enumerable
    assert_equal [[:a, 1], [:b, 2]], @meta.to_a
    assert_equal %i[a b], @meta.map { |key, _| key }
    assert_kind_of Enumerator, @meta.each
    assert_same @meta, @meta.each { |_k, _v| nil }
  end

  def test_each_pair_alias
    pairs = []
    @meta.each_pair { |key, value| pairs << [key, value] }

    assert_equal [[:a, 1], [:b, 2]], pairs
  end

  def test_dig
    meta = PM::Metadata.new(a: { b: { c: 1 } })

    assert_equal 1, meta.dig(:a, :b, :c)
    assert_equal({ b: { c: 1 } }, meta.dig('a'))
    assert_nil meta.dig(:zz, :b)
  end

  def test_fetch
    assert_equal 1, @meta.fetch('a')
    assert_equal 0, @meta.fetch(:zz, 0)
    assert_equal 9, @meta.fetch(:zz) { 9 }
    assert_raises(KeyError) { @meta.fetch(:zz) }
  end

  def test_size_empty_keys_values_delete
    assert_equal 2, @meta.size
    assert_equal 2, @meta.length
    refute_empty @meta
    assert_equal %i[a b], @meta.keys
    assert_equal [1, 2], @meta.values
    assert_equal 1, @meta.delete('a')
    assert_equal %i[b], @meta.keys
    assert_empty PM::Metadata.new
  end

  def test_equality
    assert_equal PM::Metadata.new(a: 1), PM::Metadata.new('a' => 1)
    refute_equal PM::Metadata.new(a: 1), PM::Metadata.new(a: 2)
    refute_equal PM::Metadata.new(a: 1), { a: 1 }
  end

  def test_inspect_and_to_s
    assert_equal '#<PM::Metadata {a: 1, b: 2}>', @meta.inspect
    assert_equal @meta.inspect, @meta.to_s
  end

  def test_includes_assignment_used_by_renderer
    @meta.includes = []

    assert_equal [], @meta.includes
  end

  def test_no_ostruct_dependency
    refute defined?(OpenStruct), 'PM must not load ostruct'
  end
end
