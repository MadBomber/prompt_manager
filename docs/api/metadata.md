# PM::Metadata

Hash-backed metadata container with dot-notation access and predicate methods for boolean values.

## Source

`lib/pm/metadata.rb`

## Overview

`PM::Metadata` wraps a Hash with Symbol keys. It includes `Enumerable` and has no
runtime dependencies (earlier versions subclassed `OpenStruct`).

## Constructor

### Metadata.new(hash = {}) → Metadata

Creates a new metadata object. Keys may be Strings or Symbols; they are stored as Symbols. All keys become accessible via dot notation. Boolean values also get predicate methods.

```ruby
meta = PM::Metadata.new(title: 'Hello', shell: true, erb: false)

meta.title   #=> "Hello"
meta.shell   #=> true
meta.shell?  #=> true
meta.erb     #=> false
meta.erb?    #=> false
```

## Dot Notation Access

All YAML keys from the front matter are accessible as methods:

```ruby
parsed = PM.parse("---\ntitle: Test\nprovider: openai\nmodel: gpt-4\n---\nContent")

parsed.metadata.title     #=> "Test"
parsed.metadata.provider  #=> "openai"
parsed.metadata.model     #=> "gpt-4"
parsed.metadata.missing   #=> nil
```

Assignment works too:

```ruby
parsed.metadata.model = 'gpt-4o'
```

A key named like a public `Object` method (`hash`, `display`, `method`, `name`,
`format`) still resolves to its value. A small set of methods that Ruby itself relies
on (`class`, `object_id`, `send`, `respond_to?`, `to_h`, `inspect`, and the like) is
never shadowed; read those keys with `[]`.

## Predicate Methods

Boolean keys (`true` or `false` values) automatically get a `?`-suffixed predicate method:

```ruby
meta = PM::Metadata.new(shell: true, verbose: false)

meta.shell?    #=> true
meta.verbose?  #=> false
```

Non-boolean keys do not get predicate methods:

```ruby
meta = PM::Metadata.new(title: 'Test')
meta.respond_to?(:title?)  #=> false
```

## Hash-like Methods

| Method | Description |
|---|---|
| `[](key)` / `[]=(key, value)` | Read and write by String or Symbol key |
| `key?(key)` | Whether the key is present |
| `keys` / `values` | Symbol keys and their values |
| `fetch(key, *default, &block)` | As `Hash#fetch` |
| `dig(*keys)` | As `Hash#dig` |
| `delete(key)` | Remove a key, returning its value |
| `each` / `each_pair` | Yield `[key, value]`; `Enumerable` is included |
| `size` / `length` / `empty?` | Counts |
| `to_h` | A copy of the underlying Hash (Symbol keys) |
| `==` | Compares with another `Metadata` or a Hash |
| `respond_to?(name)` | True for present keys and their predicates |

```ruby
meta.to_h            #=> { title: "Test", shell: true, erb: true }
meta[:title]         #=> "Test"
meta['title']        #=> "Test"
meta.dig(:parameters, 'code')
meta.map { |k, v| "#{k}=#{v}" }
```

## File-Specific Keys

When `PM.parse` reads from a file, these keys are added automatically:

| Key | Type | Description |
|-----|------|-------------|
| `directory` | String | Absolute path to the parent directory |
| `name` | String | Filename (e.g., `review.md`) |
| `created_at` | Time | File birthtime, or `ctime` where the filesystem has none |
| `modified_at` | Time | Last modification timestamp |

## Special Keys

### parameters

The `parameters` mapping from YAML front matter, or `nil` when absent. Keys are Strings as written in the YAML:

```ruby
parsed.metadata.parameters
#=> {"language" => "ruby", "code" => nil}
```

Keys with `nil` values are required parameters. Keys with any other value are defaults. `parsed.parameters` returns the same mapping, or `{}` when absent.

### includes

Populated after `to_s` is called. Contains a tree of included files:

```ruby
parsed.metadata.includes
#=> [{ path: "/path/to/header.md", depth: 1, metadata: {...}, includes: [] }]
```

This is `nil` before `to_s` and is reset on each `to_s` call.

### shell and erb

Control processing behavior. Always present after parsing: the file's value when it
gives one (and the configuration is not locked), otherwise the global default. Front
matter may spell them as YAML booleans or the strings `true`, `false`, `yes`, `no`,
`on`, `off`.
