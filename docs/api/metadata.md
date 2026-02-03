# PM::Metadata

OpenStruct-based metadata container with automatic predicate methods for boolean values.

## Source

`lib/pm/metadata.rb`

## Inheritance

```
OpenStruct
  └── PM::Metadata
```

## Constructor

### Metadata.new(hash = {}) → Metadata

Creates a new metadata object. All hash keys become accessible via dot notation. Boolean values also get predicate methods.

```ruby
meta = PM::Metadata.new(title: 'Hello', shell: true, erb: false)

meta.title   #=> "Hello"
meta.shell   #=> true
meta.shell?  #=> true
meta.erb     #=> false
meta.erb?    #=> false
```

## Dot Notation Access

All YAML keys from the front-matter are accessible as methods:

```ruby
parsed = PM.parse("---\ntitle: Test\nprovider: openai\nmodel: gpt-4\n---\nContent")

parsed.metadata.title     #=> "Test"
parsed.metadata.provider  #=> "openai"
parsed.metadata.model     #=> "gpt-4"
```

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

## File-Specific Keys

When `PM.parse` reads from a file, these keys are added automatically:

| Key | Type | Description |
|-----|------|-------------|
| `directory` | String | Absolute path to the parent directory |
| `name` | String | Filename (e.g., `review.md`) |
| `created_at` | Time | File creation timestamp |
| `modified_at` | Time | Last modification timestamp |

## Special Keys

### parameters

The `parameters` hash from YAML front-matter:

```ruby
parsed.metadata.parameters
#=> {"language" => "ruby", "code" => nil}
```

Keys with `nil` values are required parameters. Keys with any other value are defaults.

### includes

Populated after `to_s` is called. Contains a tree of included files:

```ruby
parsed.metadata.includes
#=> [{ path: "/path/to/header.md", depth: 1, metadata: {...}, includes: [] }]
```

This is `nil` before `to_s` and is reset on each `to_s` call.

### shell and erb

Control processing behavior. Default to `true` when not specified in the YAML. The global configuration default is applied during metadata construction.
