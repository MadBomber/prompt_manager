# Constants

Regular expressions, markers, and key lists defined in the `PM` module.

## Source

`lib/pm.rb`, `lib/pm/parsed.rb`, `lib/pm/shell.rb`, `lib/pm/version.rb`

## Reference

### PM::VERSION

```ruby
PM::VERSION  #=> the gem version, e.g. "1.1.0"
```

Defined in `lib/pm/version.rb`.

### PM::METADATA_REGEXP

Matches YAML front matter delimited by `---` fences at the start of the document (leading whitespace allowed). Captures the YAML content between the fences and the remaining body.

Used internally by `PM.parse` to separate metadata from content.

### PM::HTML_COMMENT_REGEXP

Matches HTML comments (`<!-- ... -->`), including multiline comments.

Used by `PM.strip_comments`.

### PM::ENV_VAR_REGEXP

Matches environment variable references in two forms:

- `${VAR}` -- braced form (captured in group 1)
- `$VAR` -- bare form (captured in group 2)

Only matches UPPERCASE variable names (`[A-Z_][A-Z0-9_]*`). Lowercase names are intentionally ignored to avoid conflicts with ERB and other syntax.

Used by `PM.expand_shell`.

### PM::COMMAND_START

```ruby
PM::COMMAND_START  #=> "$("
```

String marker that identifies the start of a command substitution. The shell expander reads from here to the matching close parenthesis, honouring nesting.

### PM::FLAG_KEYS

```ruby
PM::FLAG_KEYS  #=> ["shell", "erb"]
```

The front matter keys that toggle pipeline stages. Each is validated and resolved against the global configuration when metadata is built.

### PM::TRUE_WORDS / PM::FALSE_WORDS

The strings accepted for a flag besides YAML booleans: `true`, `yes`, `on` and `false`, `no`, `off` (case-insensitive).

### PM::DERIVED_METADATA_KEYS

```ruby
PM::DERIVED_METADATA_KEYS  #=> [:directory, :name, :created_at, :modified_at, :includes]
```

Metadata keys PM adds itself when parsing a file or rendering. `Parsed#to_markdown` leaves them out so a prompt round-trips.
