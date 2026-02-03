# Custom Directives

Register custom methods that become available inside ERB templates.

## Registering a Directive

```ruby
PM.register(:read) { |_ctx, path| File.read(path) }
PM.register(:env)  { |_ctx, key| ENV.fetch(key, '') }
PM.register(:run)  { |_ctx, cmd| `#{cmd}`.chomp }
```

Use them in any prompt file:

```markdown
---
title: Deploy Prompt
---
Hostname: <%= read '/etc/hostname' %>
Environment: <%= env 'DEPLOY_ENV' %>
Recent commits: <%= run 'git log --oneline -5' %>
```

## Aliases

Register multiple names for the same directive by passing additional names:

```ruby
PM.register(:webpage, :website, :web) { |_ctx, url| fetch_page(url) }
```

All names point to the same block. Use any of them in ERB:

```markdown
<%= webpage 'https://example.com' %>
<%= web 'https://example.com' %>
```

Duplicate detection still applies — if any name is already registered, an error is raised.

## The RenderContext

The first argument to every directive block is a `PM::RenderContext` with access to the current render state:

| Field | Type | Description |
|-------|------|-------------|
| `directory` | String | Directory of the file being rendered |
| `params` | Hash | Merged parameter values |
| `metadata` | PM::Metadata | Current file's metadata |
| `depth` | Integer | Include nesting depth (0 for top-level) |
| `included` | Set | File paths already in the include chain |

```ruby
PM.register(:current_file) { |ctx| ctx.metadata.name || 'unknown' }
PM.register(:nesting) { |ctx| ctx.depth.to_s }
```

The context is always the first argument. Additional arguments come from the ERB call:

```ruby
PM.register(:greet) { |_ctx, name| "Hello, #{name}!" }
```

```markdown
<%= greet 'Alice' %>
```

## Duplicate Registration

Registering a name that already exists raises an error:

```ruby
PM.register(:include) { |_ctx, path| path }
#=> RuntimeError: Directive already registered: include
```

This protects built-in directives from being overwritten.

## Resetting Directives

Remove all custom directives and restore only the built-ins:

```ruby
PM.reset_directives!
```

After reset, only `include` is registered.

## Directives in Included Files

Custom directives are available in included files too. They share the same directive registry:

```markdown
<!-- parent.md -->
<%= include 'child.md' %>

<!-- child.md -->
<%= read '/etc/hostname' %>
```

## Name Format

Both symbols and strings are accepted:

```ruby
PM.register(:my_helper) { |_ctx| "works" }
PM.register('other_helper') { |_ctx| "also works" }
```

## Listing Directives

```ruby
PM.directives
#=> { include: #<Proc>, read: #<Proc>, ... }
```
