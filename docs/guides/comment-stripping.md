# Comment Stripping

HTML comments are stripped before any other processing stage.

## Automatic Stripping

Comments are removed during `PM.parse`:

```markdown
<!-- This comment will be removed -->
---
title: My Prompt
---
Content here. <!-- This too -->
```

After parsing:

```ruby
parsed = PM.parse(source)
parsed.content  #=> "Content here. "
```

The comment text is removed; surrounding whitespace and newlines stay where they were.

## Multiline Comments

Multiline comments are fully removed:

```markdown
<!--
This entire block
is removed
-->
---
title: Example
---
Visible content.
```

## Comments Before Metadata

Comments before the YAML front matter are stripped first, so the metadata parser sees clean input:

```markdown
<!-- Editor note: draft version -->
---
title: My Prompt
---
Content
```

The blank line left behind by the comment is tolerated: front matter is recognised
after leading whitespace.

## Comments Inside Code Fences

Comment stripping is a plain text pass and does not know about fenced code blocks.
A `<!-- ... -->` inside a fence is removed too.

## Direct Access

The comment stripping method is available as a standalone utility:

```ruby
PM.strip_comments("Hello <!-- removed --> World")
#=> "Hello  World"
```

## Use Cases

- **Editor notes** -- Leave comments for prompt authors that don't appear in the rendered output
- **Disabled sections** -- Temporarily comment out parts of a prompt
- **Documentation** -- Annotate prompt files without affecting the AI input
