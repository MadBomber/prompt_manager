# Shell Expansion

Shell expansion replaces environment variable references and command substitutions with their values at parse time.

## Syntax

| Pattern | Description | Example |
|---------|-------------|---------|
| `$VAR` | Environment variable | `$USER` |
| `${VAR}` | Environment variable (braced) | `${HOME}` |
| `$(command)` | Command substitution | `$(date +%Y-%m-%d)` |
| `\$` | Literal dollar sign | `\$100` writes `$100` |

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

### Command output is inert

Expansion is a single left-to-right pass. Whatever a command prints is spliced into
the content verbatim and **not** scanned again:

```ruby
PM.expand_shell(%q{$(printf '$HOME')})   #=> "$HOME"
```

When ERB is enabled for the prompt, any `<%` in command output or in an environment
variable's value, or one formed where an expansion meets the text beside it, is escaped
to `<%%` so it cannot open a tag in the later ERB pass. The rendered result shows the
literal `<%`. An expansion written inside an ERB tag is part of that Ruby code and is
not escaped; see [Security](security.md).

### Standard error

A command's stderr is not part of the content. On success it is forwarded to the
process's `$stderr`. On failure it is included in the error.

### Failed Commands

A command that exits with a non-zero status raises `PM::ShellCommandError`:

```ruby
PM.parse_string("Output: $(exit 1)")
#=> PM::ShellCommandError: Shell command failed (exit 1): exit 1
```

The error exposes `#command`, `#status` (a `Process::Status`), and `#stderr`.

### Unmatched `$(`

An opening `$(` with no closing parenthesis raises `PM::ShellExpansionError`
(the superclass of `PM::ShellCommandError`):

```ruby
PM.expand_shell("Total: $(echo")
#=> PM::ShellExpansionError: Unmatched $( in shell expansion: $(echo
```

## Escaping

Write `\$` to produce a literal `$`:

```markdown
Price: \$100
Shell syntax for the reader: \$(ls)
```

```ruby
#=> "Price: $100\nShell syntax for the reader: $(ls)\n"
```

## Fenced Code Blocks

Lines inside a fenced code block (``` or ~~~, with an optional language tag) are copied
through untouched, so a prompt can show shell syntax to the model without running it:

````markdown
Run this:

```bash
echo $HOME && $(dangerous)
```

Your home is $HOME.
````

Only the last `$HOME` is expanded. A fence closes at a line that starts with at least
as many of the same fence characters.

## Direct Access

Shell expansion is available as a standalone method:

```ruby
PM.expand_shell("Hello $USER from $(hostname)")
#=> "Hello dewayne from venus"

PM.expand_shell(string, erb_safe: true)   # also escapes <% in command output and env var values
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

Per-file metadata overrides the global setting unless the configuration is locked
with `PM.config.lock!`. See [Configuration](../getting-started/configuration.md#locking).

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
