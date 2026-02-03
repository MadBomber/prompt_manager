# Constants

Regular expressions and markers defined in the `PM` module.

## Source

`lib/pm.rb` and `lib/pm/shell.rb`

## Reference

### PM::VERSION

```ruby
PM::VERSION  #=> "1.0.0"
```

Current version of the PM library. Defined in `lib/pm/version.rb`.

### PM::METADATA_REGEXP

```ruby
PM::METADATA_REGEXP
```

Matches YAML front-matter delimited by `---` fences. Captures the YAML content between the fences and the remaining body.

Used internally by `PM.parse` to separate metadata from content.

### PM::HTML_COMMENT_REGEXP

```ruby
PM::HTML_COMMENT_REGEXP
```

Matches HTML comments (`<!-- ... -->`), including multiline comments. Uses the `m` (multiline) flag for dot-matches-newline behavior.

Used by `PM.strip_comments`.

### PM::ENV_VAR_REGEXP

```ruby
PM::ENV_VAR_REGEXP
```

Matches environment variable references in two forms:

- `${VAR}` -- braced form (captured in group 1)
- `$VAR` -- bare form (captured in group 2)

Only matches UPPERCASE variable names (`[A-Z_][A-Z0-9_]*`). Lowercase names are intentionally ignored to avoid conflicts with ERB and other syntax.

Used by `PM.expand_shell` during the environment variable expansion phase.

### PM::COMMAND_START

```ruby
PM::COMMAND_START  #=> "$("
```

String marker that identifies the start of a command substitution. Used by the shell expansion parser to find `$(command)` sequences with proper handling of nested parentheses.
