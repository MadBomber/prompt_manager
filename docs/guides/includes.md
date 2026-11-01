# Including Files

Two directives compose a prompt from other files. `include` parses and renders
another prompt; `insert` (alias `read`) copies any file in verbatim.

## Basic Usage

```markdown
---
title: Full Review
parameters:
  code: null
---
<%= include 'common/header.md' %>

Review this code:
<%= code %>

<%= include 'common/footer.md' %>
```

```ruby
parsed = PM.parse('full_review.md')
puts parsed.to_s('code' => File.read('app.rb'))
```

## How Includes Work

Each included file goes through the full processing pipeline:

1. HTML comments stripped
2. YAML metadata extracted
3. Shell expansion applied
4. ERB rendered (with the parent's parameter values)

The included file's rendered content replaces the `<%= include ... %>` tag. The file
can have any extension; `.md` is conventional but not required.

## Path Resolution

Include paths are resolved relative to the **parent file's directory**:

```
prompts/
  review.md          # contains: <%= include 'common/header.md' %>
  common/
    header.md        # resolved from prompts/common/header.md
```

Absolute paths work too. Paths are not confined to `prompts_dir`.

## Parameter Passing

The parent's parameter values are passed to included files. Child files can use the same parameter names:

```markdown
<!-- parent.md -->
---
parameters:
  name: null
---
<%= include 'greeting.md' %>
Done.
```

```markdown
<!-- greeting.md -->
---
title: Greeting
---
Hello, <%= name %>!
```

```ruby
parsed = PM.parse('parent.md')
parsed.to_s('name' => 'Alice')
#=> "Hello, Alice!\nDone."
```

## Nested Includes

Includes can be nested. File A can include File B, which includes File C:

```markdown
<!-- a.md -->
<%= include 'b.md' %>

<!-- b.md -->
<%= include 'c.md' %>

<!-- c.md -->
Content from C
```

### Depth limit

Nesting is capped by `PM.config.max_include_depth` (default 10). The top-level file
is depth 0, so with the default a chain of ten nested includes works and the
eleventh raises:

```ruby
PM.parse('deep.md').to_s
#=> PM::IncludeDepthError: Include depth exceeds 10 (PM.config.max_include_depth): /path/to/eleventh.md
```

Set `max_include_depth` to `nil` to remove the limit.

## Including the Same File Twice

A file may be included more than once in one prompt, for example a separator between
sections. Only a true cycle is an error.

```markdown
<%= include 'sep.md' %>
Section one
<%= include 'sep.md' %>
Section two
```

## Circular Include Detection

PM tracks the chain of files currently being rendered. Including a file that is
already an ancestor raises `PM::CircularIncludeError`:

```markdown
<!-- circular_a.md -->
<%= include 'circular_b.md' %>

<!-- circular_b.md -->
<%= include 'circular_a.md' %>
```

```ruby
PM.parse('circular_a.md').to_s
#=> PM::CircularIncludeError: Circular include detected: /path/to/circular_a.md
```

## Includes Metadata

After calling `to_s`, the parent's metadata has an `includes` key with a tree of what was included:

```ruby
parsed = PM.parse('full_review.md')
parsed.to_s('code' => source)

parsed.metadata.includes
#=> [
#     {
#       path:     "/prompts/common/header.md",
#       depth:    1,
#       metadata: { title: "Header", shell: true, erb: true, directory: "...", name: "header.md", ... },
#       includes: []
#     },
#     {
#       path:     "/prompts/common/footer.md",
#       depth:    1,
#       metadata: { title: "Footer", ... },
#       includes: []
#     }
#   ]
```

Nested includes form a tree: each entry's `includes` array contains its own children.
Each entry's `metadata` is a plain Hash with Symbol keys.

The `includes` array is `nil` before `to_s` is called and is reset on each call.

## `insert` / `read`: Raw File Insertion

Use `insert` (or its alias `read`) to insert a file's content verbatim. Unlike `include`, the content is not parsed, shell-expanded, or ERB-rendered:

````markdown
---
title: Code Review
---
Review this code:

```ruby
<%= insert 'src/app.rb' %>
```
````

### Differences from `include`

| | `insert` / `read` | `include` |
|---|---|---|
| File types | Any | Any (conventionally `.md`) |
| Front matter | Kept as text | Parsed into the child's metadata |
| ERB in content | Preserved as literal text | Rendered |
| Shell expansion | Not applied | Applied |
| Parameters | n/a | Parent values passed down |
| Recursion | None | Nested, up to `max_include_depth` |
| Metadata tracking | None | `metadata.includes` tree |
| Needs a file context | No (absolute paths work anywhere) | Yes |

### Path resolution

Same as `include`: paths resolve relative to the parent file's directory. Absolute paths work from any context, including string-parsed prompts.

### Missing files

Raises `PM::FileNotFoundError`:

```ruby
PM.parse_string("<%= insert '/no/such/file' %>").to_s
#=> PM::FileNotFoundError: insert: file not found: /no/such/file
```

## Requirements

- The `include` directive requires file context. Using it with string-parsed prompts raises `PM::IncludeContextError`:

```ruby
PM.parse_string("<%= include 'other.md' %>").to_s
#=> PM::IncludeContextError: include requires a file context (use PM.parse with a file path)
```

- When `erb: false`, directives do not execute and `metadata.includes` is an empty array.

## Error summary

| Error | Cause |
|---|---|
| `PM::CircularIncludeError` | File is already in the current include chain |
| `PM::IncludeDepthError` | Nesting deeper than `max_include_depth` |
| `PM::IncludeContextError` | `include` from a string-parsed prompt |
| `PM::FileNotFoundError` | `insert` / `read` target missing or not a regular file |
| `Errno::ENOENT` | `include` target missing |

All but `Errno::ENOENT` descend from `PM::IncludeError` or `PM::Error`. See the
[Errors reference](../api/errors.md).
