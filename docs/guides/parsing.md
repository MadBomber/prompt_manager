# Parsing Prompts

`PM.parse` is the main entry point. It accepts a file path, a Symbol, a single word, or a raw string.

## File Paths

A source is treated as a file path when it:

- Is a `Pathname` object
- Responds to `to_path`
- Is a String ending in `.md`
- Is a Symbol (`.md` is appended, e.g. `:code_review` → `code_review.md`)
- Is a single word containing only letters, digits, or underscores (`.md` is appended, e.g. `"code_review"` → `code_review.md`)

```ruby
# String file path
parsed = PM.parse('code_review.md')

# Pathname
parsed = PM.parse(Pathname.new('code_review.md'))

# Symbol (basename — .md appended)
parsed = PM.parse(:code_review)

# Single word (basename — .md appended)
parsed = PM.parse('code_review')
```

When parsing a file, PM adds these keys to the metadata automatically:

| Key | Type | Description |
|-----|------|-------------|
| `directory` | String | Absolute path to the file's parent directory |
| `name` | String | Filename (e.g., `code_review.md`) |
| `created_at` | Time | File creation timestamp |
| `modified_at` | Time | Last modification timestamp |

### prompts_dir

Relative file paths are resolved against `PM.config.prompts_dir`:

```ruby
PM.configure { |c| c.prompts_dir = '~/.prompts' }

PM.parse('agents/summarize.md')
#=> reads ~/.prompts/agents/summarize.md
```

Absolute paths bypass `prompts_dir`:

```ruby
PM.parse('/etc/prompts/system.md')
#=> reads /etc/prompts/system.md regardless of prompts_dir
```

## Raw Strings

Any other string is parsed directly:

```ruby
parsed = PM.parse("---\ntitle: Hello\n---\nContent here")

parsed.metadata.title  #=> "Hello"
parsed.content         #=> "\nContent here\n"
```

String-parsed prompts do not have `directory`, `name`, `created_at`, or `modified_at` in their metadata.

!!! warning "Include limitations"
    The `include` directive requires file context to resolve relative paths. It raises an error when used with string-parsed prompts.

### PM.parse_string vs PM.parse

Because `PM.parse` treats single words as prompt IDs (appending `.md` and looking them up as files), short strings like `"hello"` or `"summarize"` will trigger a file lookup instead of being parsed as content. Use `PM.parse_string` to always parse a string as content:

```ruby
# PM.parse treats single words as prompt IDs
PM.parse('hello')          #=> looks for hello.md in prompts_dir
PM.parse('summarize')      #=> looks for summarize.md in prompts_dir

# PM.parse_string always parses as string content
PM.parse_string('hello')          #=> Parsed with content "hello"
PM.parse_string('summarize')      #=> Parsed with content "summarize"

# Multi-word strings without .md extension work the same in both
PM.parse("Hello world")           #=> Parsed with content "Hello world"
PM.parse_string("Hello world")    #=> Parsed with content "Hello world"
```

Use `PM.parse_string` when:

- Your input may be a single word that should not be treated as a file
- You know the source is always a string, never a file path
- You want to skip the file-detection logic entirely

## Metadata Extraction

YAML front-matter is delimited by `---` fences:

```markdown
---
title: My Prompt
provider: openai
model: gpt-4
temperature: 0.3
---
The prompt content starts here.
```

All YAML keys become accessible via dot notation on the `PM::Metadata` object:

```ruby
parsed.metadata.title        #=> "My Prompt"
parsed.metadata.provider     #=> "openai"
parsed.metadata.temperature  #=> 0.3
```

Boolean keys also get predicate methods:

```ruby
parsed.metadata.shell   #=> true
parsed.metadata.shell?  #=> true
```

### No Metadata

Files without front-matter are valid. The metadata object is empty and the entire content is preserved:

```ruby
parsed = PM.parse("Just plain text")
parsed.metadata.title  #=> nil
parsed.content         #=> "Just plain text"
```

### Bracket Accessor

You can also access metadata with bracket notation:

```ruby
parsed[:title]  #=> "My Prompt"
```

## Pipeline Stages

After parsing, the content has been through these stages:

1. HTML comments stripped
2. YAML metadata extracted
3. Shell expansion applied (if `shell: true`)

ERB rendering happens later, on demand, when `to_s` is called.
