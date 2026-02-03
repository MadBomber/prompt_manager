# Shell Expansion

Shell expansion replaces environment variable references and command substitutions with their values at parse time.

## Syntax

| Pattern | Description | Example |
|---------|-------------|---------|
| `$VAR` | Environment variable | `$USER` |
| `${VAR}` | Environment variable (braced) | `${HOME}` |
| `$(command)` | Command substitution | `$(date +%Y-%m-%d)` |

## Environment Variables

```markdown
---
title: Info
---
Current user: $USER
Home directory: ${HOME}
```

After parsing:

```ruby
parsed = PM.parse('info.md')
parsed.content
#=> "Current user: dewayne\nHome directory: /Users/dewayne\n"
```

Only UPPERCASE variable names are expanded. Lowercase names like `$foo` are left as-is.

Missing environment variables are replaced with an empty string.

## Command Substitution

```markdown
---
title: Context
---
Date: $(date +%Y-%m-%d)
Branch: $(git rev-parse --abbrev-ref HEAD)
```

Commands are executed via the shell and replaced with their stdout (trailing newline stripped).

### Nested Commands

Nested parentheses are handled correctly:

```markdown
$(echo $(echo hello))
```

### Failed Commands

A command that exits with a non-zero status raises `RuntimeError`:

```ruby
PM.parse("Output: $(exit 1)")
#=> RuntimeError: Command failed with exit status 1: exit 1
```

## Direct Access

Shell expansion is available as a standalone method:

```ruby
PM.expand_shell("Hello $USER from $(hostname)")
#=> "Hello dewayne from venus"
```

## Disabling Shell Expansion

Set `shell: false` in the file's YAML metadata:

```markdown
---
title: Raw
shell: false
---
This $USER reference is preserved as-is.
```

Or disable globally:

```ruby
PM.configure { |c| c.shell = false }
```

Per-file metadata always overrides the global setting. A file with `shell: true` gets shell expansion even when the global default is `false`.

## Interaction with ERB

Shell expansion happens at parse time (step 3 of the pipeline). ERB rendering happens later when `to_s` is called (step 4). This means shell references in the raw template are expanded before ERB sees the content.

If you need dynamic shell output at render time, use a custom directive instead:

```ruby
PM.register(:sh) { |_ctx, cmd| `#{cmd}`.chomp }
```

```markdown
---
title: Dynamic
---
Branch: <%= sh 'git rev-parse --abbrev-ref HEAD' %>
```
