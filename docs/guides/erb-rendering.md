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
parsed.to_s  #=> "Result: 4\nToday: 2026-11-01\n"
```

ERB is full Ruby. Anything a template can express, it can run. See
[Security](security.md).

## Template Parameters

Parameters declared in the YAML front matter are available as local methods inside ERB:

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

See [Parameters](parameters.md) for required vs default values, name resolution, and strict mode.

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

PM ships three built-in directives:

- **`include`** -- Parse and render another prompt file in place. See [Including Files](includes.md).
- **`insert`** -- Copy any file in verbatim.
- **`read`** -- Alias of `insert`.

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
- Parameters are ignored (missing required parameters are not an error)
- Directives do not execute
- `metadata.includes` is an empty array after `to_s`

### Global Default

```ruby
PM.configure { |c| c.erb = false }
```

Per-file metadata overrides the global setting unless the configuration is locked
with `PM.config.lock!`. See [Configuration](../getting-started/configuration.md#locking).

## Pipeline Position

ERB rendering is the last stage of the pipeline, executed on demand:

1. Strip HTML comments
2. Extract YAML metadata
3. Shell expansion (at parse time)
4. **ERB rendering** (at `to_s` time)

This means shell variables are already expanded before ERB sees the content. If content contains both `$VAR` and `<%= param %>`, the shell variable is resolved first, then ERB fills in the parameters. Command output cannot smuggle ERB into stage 4: any `<%` a command prints is escaped during stage 3.

## Errors

| Situation | Error |
|---|---|
| Required parameter missing | `PM::MissingParameterError` |
| Unknown name in strict mode | `PM::UnknownParameterError` |
| Unknown name called with arguments, strict mode off | `NoMethodError` |
| ERB that does not compile | `SyntaxError` |

For a prompt read from a file, including one pulled in with `include`, the
backtrace of an error raised inside ERB names that file (`/path/to/inner.md:2`)
instead of `(erb):2`. Line numbers count from the first line after the front
matter. String-parsed prompts still show `(erb)`.
