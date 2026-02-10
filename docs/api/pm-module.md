# PM Module

The top-level `PM` module is the primary interface. All public methods are class methods on `PM`.

## Parsing

### PM.parse(source) → Parsed

Parse a file or string and return a `PM::Parsed` object.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `source` | String, Symbol, Pathname | File path (`.md` extension or Pathname), Symbol, single word, or raw string |

**Returns:** `PM::Parsed` (Struct with `metadata` and `content`)

**Behavior:**

- If `source` is a Symbol or a single word (letters, digits, underscores only), `.md` is appended and it is treated as a file basename
- If `source` is a Pathname, responds to `to_path`, or is a String ending in `.md`, it is treated as a file path
- File paths are resolved relative to `PM.config.prompts_dir` (unless absolute)
- File parsing adds `directory`, `name`, `created_at`, `modified_at` to metadata
- Processing pipeline: strip comments → extract YAML → shell expansion

```ruby
# File
parsed = PM.parse('review.md')

# Symbol or single word (basename — .md appended)
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

**Returns:** `PM::Parsed` (Struct with `metadata` and `content`)

**Behavior:**

- Always parses the input as string content — never looks up files
- Runs the same pipeline as `PM.parse`: strip comments → extract YAML → shell expansion
- Does not add `directory`, `name`, `created_at`, or `modified_at` to metadata

```ruby
# Single words are parsed as content, not treated as file basenames
parsed = PM.parse_string('hello')
parsed.content  #=> "hello"

# Strings with YAML front-matter work as expected
parsed = PM.parse_string("---\ntitle: Hello\n---\nContent")
parsed.metadata.title  #=> "Hello"
parsed.content         #=> "Content\n"
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

Yields the configuration instance for block-style configuration.

```ruby
PM.configure do |config|
  config.prompts_dir = '~/.prompts'
  config.shell = true
  config.erb = true
end
```

---

## Utilities

### PM.strip_comments(string) → String

Remove all HTML comments (`<!-- ... -->`) from the string, including multiline.

```ruby
PM.strip_comments("Hello <!-- removed --> World")
#=> "Hello  World"
```

### PM.expand_shell(string) → String

Expand shell references in the string.

- `$VAR` and `${VAR}` → environment variable value (empty string if unset)
- `$(command)` → command stdout (trailing newline stripped)

Only UPPERCASE variable names are expanded.

```ruby
PM.expand_shell("User: $USER, Date: $(date +%Y-%m-%d)")
#=> "User: dewayne, Date: 2025-01-15"
```

**Raises:** `RuntimeError` if a command exits with non-zero status.

---

## Directives

### PM.register(*names, &block) → nil

Register one or more named directives available in ERB templates. Multiple names register the same block under each name (aliases).

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `*names` | Symbols, Strings | One or more directive names |
| `block` | Proc | Receives `RenderContext` as first arg, then user args |

**Raises:** `RuntimeError` if any name is already registered.

```ruby
PM.register(:env) { |_ctx, key| ENV.fetch(key, '') }
PM.register(:webpage, :website, :web) { |_ctx, url| fetch_page(url) }
```

### PM.directives → Hash

Returns the current directive registry.

```ruby
PM.directives
#=> { include: #<Proc>, env: #<Proc> }
```

### PM.reset_directives! → nil

Remove all custom directives and re-register only the built-in `include` directive.

```ruby
PM.reset_directives!
PM.directives.keys  #=> [:include]
```
