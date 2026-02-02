# ERB Rendering

ERB templates are evaluated on demand when `to_s` is called.

## Basics

Any `<%= expression %>` in the content is evaluated as Ruby:

```markdown
---
title: Math
---
Result: <%= 2 + 2 %>
Today: <%= Time.now.strftime('%Y-%m-%d') %>
```

```ruby
parsed = PM.parse('math.md')
parsed.to_s  #=> "Result: 4\nToday: 2025-01-15\n"
```

## Template Parameters

Parameters declared in the YAML front-matter are available as local methods inside ERB:

```markdown
---
title: Greeting
parameters:
  name: World
---
Hello, <%= name %>!
```

```ruby
parsed = PM.parse('greeting.md')
parsed.to_s                    #=> "Hello, World!"
parsed.to_s('name' => 'Alice') #=> "Hello, Alice!"
```

See [Parameters](parameters.md) for details on required vs default values.

## Registered Directives

Custom directives registered with `PM.register` are also available in ERB:

```ruby
PM.register(:upcase) { |_ctx, str| str.upcase }
```

```markdown
---
title: Example
---
<%= upcase 'hello' %>
```

See [Custom Directives](custom-directives.md) for the full guide.

## Built-in Directives

PM includes one built-in directive:

- **`include`** -- Include and render another prompt file. See [Including Files](includes.md).

## Disabling ERB

Set `erb: false` in the file's YAML metadata:

```markdown
---
title: Raw Template
erb: false
---
This <%= expression %> is preserved as-is.
```

When ERB is disabled:

- `to_s` returns the content without template evaluation
- Parameters are ignored
- The `include` directive does not execute
- `metadata.includes` is an empty array after `to_s`

### Global Default

```ruby
PM.configure { |c| c.erb = false }
```

Per-file metadata always overrides the global setting. A file with `erb: true` gets ERB rendering even when the global default is `false`.

## Pipeline Position

ERB rendering is the last stage of the pipeline, executed on demand:

1. Strip HTML comments
2. Extract YAML metadata
3. Shell expansion (at parse time)
4. **ERB rendering** (at `to_s` time)

This means shell variables are already expanded before ERB sees the content. If content contains both `$VAR` and `<%= param %>`, the shell variable is resolved first, then ERB fills in the parameters.
