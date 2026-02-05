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

After reset, only the built-in directives are registered: `include`, `insert`, and `read`.

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

## Class-Based Directives

For organized groups of directives, subclass `PM::Directive`:

```ruby
class MyDirectives < PM::Directive
  desc "Fetch environment variable"
  def env(ctx, key)
    ENV.fetch(key, '')
  end

  desc "Run a shell command"
  def run(ctx, cmd)
    `#{cmd}`.chomp
  end
  alias_method :exec, :run

  # No desc — not registered as a directive
  def helper
    "internal"
  end
end

PM::Directive.register_all
```

`desc` marks the next method as a directive. Methods without `desc` are ordinary helpers and won't be registered. `alias_method` aliases are detected automatically via `UnboundMethod#original_name`.

### Category name

The class name determines a category heading (useful for help output):

```ruby
MyDirectives.category_name  #=> "My"
PM::CoreDirectives.category_name  #=> "Core"
```

The last segment of the class name is used, with `Directives` stripped and camelCase split.

### Dispatch customization

Override `build_dispatch_block` to customize how methods are called when dispatched through `PM.directives`:

```ruby
class MyDirectives < PM::Directive
  class << self
    # Default: proc { |ctx, *args| inst.send(method_name, ctx, *args) }
    def build_dispatch_block(inst, method_name)
      proc { |_ctx, *args| inst.send(method_name, args.flatten) }
    end
  end
end
```

### Subclass tracking

All `PM::Directive` subclasses (direct and indirect) are tracked centrally:

```ruby
PM::Directive.directive_subclasses
#=> [PM::CoreDirectives, MyDirectives, ...]
```

`register_all` iterates this list, creates a singleton instance per subclass, and registers each described method with `PM.register`.

## Listing Directives

```ruby
PM.directives
#=> { include: #<Proc>, insert: #<Proc>, read: #<Proc>, ... }
```
