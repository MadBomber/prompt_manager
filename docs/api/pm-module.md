# PM Module

The top-level `PM` module is the primary interface. All public methods are class methods on `PM`.

## Parsing

### PM.parse(source) → Parsed

Parse a file or string and return a `PM::Parsed` object.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `source` | String, Symbol, Pathname | File path (`.md` extension or Pathname), Symbol, single word, or raw string |

**Returns:** `PM::Parsed` (a `Data` with `metadata` and `content`)

**Behavior:**

- If `source` is a Symbol or a single word (letters, digits, underscores only), `.md` is appended and it is treated as a file basename
- If `source` is a Pathname, responds to `to_path`, or is a String ending in `.md`, it is treated as a file path
- File paths are resolved relative to `PM.config.prompts_dir` (unless absolute)
- File parsing adds `directory`, `name`, `created_at`, `modified_at` to metadata
- Processing pipeline: strip comments → extract YAML → shell expansion

**Raises:** `Errno::ENOENT` for a missing file; `PM::MetadataError` for invalid front matter; `Psych::SyntaxError` for invalid YAML; `PM::ShellExpansionError` / `PM::ShellCommandError` from shell expansion.

```ruby
# File
parsed = PM.parse('review.md')

# Symbol or single word (basename, .md appended)
parsed = PM.parse(:review)      #=> parses review.md
parsed = PM.parse('review')     #=> parses review.md

# String
parsed = PM.parse("---\ntitle: Hello\n---\nContent")
```

---

### PM.parse_string(string) → Parsed

Parse a string directly through the processing pipeline, bypassing all file-detection logic. Unlike `PM.parse`, single words are never treated as prompt IDs.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `string` | String | Raw string content to parse |

**Returns:** `PM::Parsed`

**Behavior:**

- Always parses the input as string content, never looks up files
- Runs the same pipeline as `PM.parse`: strip comments → extract YAML → shell expansion
- Does not add `directory`, `name`, `created_at`, or `modified_at` to metadata

```ruby
# Single words are parsed as content, not treated as file basenames
parsed = PM.parse_string('hello')
parsed.content  #=> "hello"

# Strings with YAML front matter work as expected
parsed = PM.parse_string("---\ntitle: Hello\n---\nContent")
parsed.metadata.title  #=> "Hello"
parsed.content         #=> "Content"
```

**When to use `parse_string` instead of `parse`:**

```ruby
PM.parse('summarize')          #=> looks for summarize.md
PM.parse_string('summarize')   #=> parses "summarize" as content
```

---

## Configuration

### PM.config → Configuration

Returns the singleton `PM::Configuration` instance.

```ruby
PM.config.prompts_dir  #=> ''
PM.config.shell        #=> true
```

### PM.configure { |config| } → Configuration

Yields the configuration instance for block-style configuration and returns it.

```ruby
PM.configure do |config|
  config.prompts_dir       = '~/.prompts'
  config.shell             = true
  config.erb               = true
  config.max_include_depth = 10
  config.strict_parameters = false
end
```

See [PM::Configuration](configuration.md) for `lock!` and the other methods.

---

## Utilities

### PM.strip_comments(string) → String

Remove all HTML comments (`<!-- ... -->`) from the string, including multiline.

```ruby
PM.strip_comments("Hello <!-- removed --> World")
#=> "Hello  World"
```

### PM.expand_shell(string, erb_safe: false) → String

Expand shell references in the string in a single left-to-right pass.

- `$VAR` and `${VAR}` → environment variable value (empty string if unset)
- `$(command)` → command stdout (trailing newline stripped); nested parentheses are matched
- `\$` → literal `$`
- Fenced code blocks (``` or ~~~) are copied through untouched
- Command output is inserted verbatim and never re-scanned
- With `erb_safe: true`, `<%` in command output and environment variable values is written as `<%%`

Only UPPERCASE variable names are expanded.

```ruby
PM.expand_shell("User: $USER, Date: $(date +%Y-%m-%d)")
#=> "User: dewayne, Date: 2026-11-01"
```

**Raises:** `PM::ShellCommandError` if a command exits non-zero (`#command`, `#status`, `#stderr`); `PM::ShellExpansionError` for an unmatched `$(`.

---

## Directives

### PM.register(*names, &block) → nil

Register one or more named directives available in ERB templates. Multiple names register the same block under each name (aliases).

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `*names` | Symbols, Strings | One or more directive names |
| `block` | Proc | Receives `RenderContext` as first arg, then user args |

**Raises:** `ArgumentError` without a block; `PM::DirectiveAlreadyRegisteredError` if any name is already registered, in which case nothing is registered.

```ruby
PM.register(:env) { |_ctx, key| ENV.fetch(key, '') }
PM.register(:webpage, :website, :web) { |_ctx, url| fetch_page(url) }
```

### PM.directives → Hash

Returns a frozen snapshot of the directive registry (Symbol keys, Proc values).

```ruby
PM.directives
#=> { include: #<Proc>, insert: #<Proc>, read: #<Proc>, env: #<Proc> }
```

### PM.directive?(name) → Boolean

Whether a directive with this name (Symbol or String) is registered.

```ruby
PM.directive?(:include)   #=> true
PM.directive?('nope')     #=> false
```

### PM.reset_directives! → nil

Remove all custom directives and re-register the built-ins from every `PM::Directive` subclass.

```ruby
PM.reset_directives!
PM.directives.keys  #=> [:include, :insert, :read]
```
