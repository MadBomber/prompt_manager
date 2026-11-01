# Custom Directives

Register custom methods that become available inside ERB templates.

## Registering a Directive

```ruby
PM.register(:env)  { |_ctx, key| ENV.fetch(key, '') }
PM.register(:run)  { |_ctx, cmd| `#{cmd}`.chomp }
PM.register(:host) { |_ctx| Socket.gethostname }
```

Use them in any prompt file:

```markdown
---
title: Deploy Prompt
---
Hostname: <%= host %>
Environment: <%= env 'DEPLOY_ENV' %>
Recent commits: <%= run 'git log --oneline -5' %>
```

`PM.register` requires a block and raises `ArgumentError` without one.

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

Registration is atomic: if any requested name is already taken, nothing is registered
and `PM::DirectiveAlreadyRegisteredError` is raised.

## The RenderContext

The first argument to every directive block is a `PM::RenderContext` with access to the current render state:

| Field | Type | Description |
|-------|------|-------------|
| `directory` | String or nil | Directory of the file being rendered (`nil` for string-parsed prompts) |
| `params` | Hash | Merged parameter values (String keys) |
| `metadata` | PM::Metadata | Current file's metadata |
| `depth` | Integer | Include nesting depth (0 for top-level) |
| `included` | Set | Paths of the ancestor files in the include chain |

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

A directive's return value is inserted as-is. It is not shell-expanded or rendered as
ERB, so a directive that fetches external content cannot have that content executed.

## Name Resolution in Templates

A bare name in a template resolves to a **parameter** first (when called with no
arguments), then to a directive. A template that declares a parameter named
`include` and also calls `include 'x.md'` gets the parameter in the first case and
the directive in the second. See [Parameters](parameters.md#name-resolution).

## Duplicate Registration

Registering a name that already exists raises `PM::DirectiveAlreadyRegisteredError`:

```ruby
PM.register(:include) { |_ctx, path| path }
#=> PM::DirectiveAlreadyRegisteredError: Directive already registered: include
```

This protects built-in directives from being overwritten.

### Registry policy

| Action | Result |
|---|---|
| `PM.register` a name nobody holds | Registered |
| `PM.register` a name that is taken (by a block or a class) | `DirectiveAlreadyRegisteredError`; no name from the call is registered |
| `register_all` for a name held by another `PM::Directive` subclass | Re-registered; the later subclass wins |
| `register_all` for a name held by a `PM.register` block | `DirectiveAlreadyRegisteredError` |
| `register_all` called again | Idempotent |

## Resetting Directives

Remove all custom directives and restore only the built-ins:

```ruby
PM.reset_directives!
PM.directives.keys   #=> [:include, :insert, :read]
```

## Directives in Included Files

Custom directives are available in included files too. They share the same directive registry:

```markdown
<!-- parent.md -->
<%= include 'child.md' %>

<!-- child.md -->
<%= env 'DEPLOY_ENV' %>
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

  # No desc: not registered as a directive
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

`register_all` iterates this list, creates a singleton instance per subclass, and registers each described method. Subclasses with no described methods are skipped.

## Listing Directives

```ruby
PM.directives
#=> { include: #<Proc>, insert: #<Proc>, read: #<Proc>, ... }

PM.directive?(:include)   #=> true
PM.directive?('nope')     #=> false
```

`PM.directives` returns a frozen snapshot. Mutating it has no effect on the registry;
use `PM.register` and `PM.reset_directives!`.

## Thread safety

The registry is process-global and not synchronized. Register directives at boot,
before rendering from multiple threads.
