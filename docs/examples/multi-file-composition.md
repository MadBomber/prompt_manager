# Multi-File Composition

Compose prompts from shared components using the `include` directive.

## Directory Structure

```
prompts/
  review.md
  common/
    system_context.md
    output_format.md
    ruby_standards.md
```

## Shared Components

`prompts/common/system_context.md`:

```markdown
---
title: System Context
---
You are a senior software engineer with expertise in <%= language %>.
Current date: $(date +%Y-%m-%d)
User: $USER
```

`prompts/common/output_format.md`:

```markdown
---
title: Output Format
---
Format your response as:
1. Summary (2-3 sentences)
2. Issues found (bulleted list)
3. Suggestions (numbered list)
4. Revised code (if applicable)
```

`prompts/common/ruby_standards.md`:

```markdown
---
title: Ruby Standards
---
Follow these Ruby conventions:
- Use snake_case for methods and variables
- Prefer single-line blocks with braces for short expressions
- Use guard clauses over nested conditionals
- Avoid monkey-patching standard library classes
```

## The Composed Prompt

`prompts/review.md`:

```markdown
---
title: Full Code Review
parameters:
  language: ruby
  code: null
---
<%= include 'common/system_context.md' %>

<%= include 'common/ruby_standards.md' %>

Review the following code:

<%= code %>

<%= include 'common/output_format.md' %>
```

## Usage

```ruby
PM.configure { |c| c.prompts_dir = './prompts' }

parsed = PM.parse('review.md')
prompt = parsed.to_s('code' => File.read('app.rb'))
```

The rendered prompt combines all four files into a single coherent prompt.

## Inspecting the Include Tree

```ruby
parsed.metadata.includes
#=> [
#     { path: ".../common/system_context.md", depth: 1, metadata: {...}, includes: [] },
#     { path: ".../common/ruby_standards.md", depth: 1, metadata: {...}, includes: [] },
#     { path: ".../common/output_format.md",  depth: 1, metadata: {...}, includes: [] }
#   ]
```

## Nested Includes

Components can include other components. For example, `system_context.md` could include a `team_info.md`:

```markdown
---
title: System Context
---
You are a senior software engineer.
<%= include 'common/team_info.md' %>
```

The include tree reflects the nesting:

```ruby
parsed.metadata.includes[0][:includes]
#=> [{ path: ".../common/team_info.md", depth: 2, metadata: {...}, includes: [] }]
```

## Benefits

- **Reuse** -- Shared components (system context, output format) written once
- **Consistency** -- Changes to a component propagate to all prompts that include it
- **Modularity** -- Swap components per use case (different standards for different languages)
- **Traceability** -- The includes tree shows exactly what went into each prompt
