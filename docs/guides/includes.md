# Including Files

The `include` directive lets you compose prompts from multiple files.

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

The included file's rendered content replaces the `<%= include ... %>` tag.

## Path Resolution

Include paths are resolved relative to the **parent file's directory**:

```
prompts/
  review.md          # contains: <%= include 'common/header.md' %>
  common/
    header.md        # resolved from prompts/common/header.md
```

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

## Circular Include Detection

PM detects circular includes and raises an error:

```markdown
<!-- circular_a.md -->
<%= include 'circular_b.md' %>

<!-- circular_b.md -->
<%= include 'circular_a.md' %>
```

```ruby
PM.parse('circular_a.md').to_s
#=> RuntimeError: Circular include detected: /path/to/circular_a.md
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
#       metadata: { title: "Header", ... },
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

Nested includes form a tree -- each entry's `includes` array contains its own children.

The `includes` array is `nil` before `to_s` is called and is reset on each call.

## Requirements

- The `include` directive requires file context. Using it with string-parsed prompts raises an error:

```ruby
PM.parse("---\n---\n<%= include 'other.md' %>").to_s
#=> RuntimeError: include requires a file context (use PM.parse with a file path)
```

- When `erb: false`, the include directive does not execute and `metadata.includes` is an empty array.
