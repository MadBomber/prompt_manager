# Configuration

PM has one global `PM::Configuration` object, reached through `PM.config` or `PM.configure`.

## Setting Defaults

```ruby
PM.configure do |config|
  config.prompts_dir       = '~/.prompts'  # default: ''
  config.shell             = true          # default: true
  config.erb               = true          # default: true
  config.max_include_depth = 10            # default: 10 (nil = unlimited)
  config.strict_parameters = false         # default: false
end
```

`PM.configure` yields the singleton and returns it.

## prompts_dir

Prepended to relative file paths passed to `PM.parse`. Absolute paths bypass it. Symbols and single words are converted to `.md` basenames first. It may be a String or a Pathname; `''` (the default) or `nil` means none, so relative paths resolve against the current directory.

```ruby
PM.configure { |c| c.prompts_dir = '/usr/share/prompts' }

PM.parse('code_review.md')
#=> reads /usr/share/prompts/code_review.md

PM.parse(:code_review)
#=> reads /usr/share/prompts/code_review.md

PM.parse('code_review')
#=> reads /usr/share/prompts/code_review.md

PM.parse('/absolute/path/review.md')
#=> reads /absolute/path/review.md (prompts_dir ignored)
```

Subdirectories work naturally:

```ruby
PM.configure { |c| c.prompts_dir = '~/.prompts' }

PM.parse('agents/summarize.md')
#=> reads ~/.prompts/agents/summarize.md
```

## shell

Controls whether shell expansion (`$VAR`, `$(command)`) runs during parsing. Defaults to `true`.

```ruby
PM.configure { |c| c.shell = false }

# All files now skip shell expansion by default
```

Per-file YAML metadata overrides the global setting unless the configuration is [locked](#locking):

```markdown
---
title: Override Example
shell: true
---
This file gets shell expansion even when the global default is false.
User: $USER
```

The front matter value may be a YAML boolean or one of the strings `true`, `false`,
`yes`, `no`, `on`, `off`. Anything else raises `PM::MetadataError`.

## erb

Controls whether ERB rendering runs during `to_s`. Defaults to `true`.

```ruby
PM.configure { |c| c.erb = false }

# All files now skip ERB rendering by default
```

Per-file metadata overrides this too, with the same rules as `shell`:

```markdown
---
title: Override Example
erb: true
---
This file renders ERB even when the global default is false.
Result: <%= 2 + 2 %>
```

## Locking

`lock!` makes the global `shell` and `erb` values final. A file's own `shell:` or
`erb:` front matter is ignored while the configuration is locked.

```ruby
PM.configure do |c|
  c.shell = false
  c.erb   = false
end
PM.config.lock!

PM.parse_string("---\nshell: true\n---\n$USER").content   #=> "$USER"

PM.config.locked?   #=> true
PM.config.unlock!   # or PM.config.locked = false
```

Use this when prompt files come from a directory other people can write to. See the
[Security guide](../guides/security.md).

## max_include_depth

The deepest `include` nesting allowed. The top-level file is depth 0; each `include`
adds one. Exceeding the limit raises `PM::IncludeDepthError`. Set it to `nil` for no limit.

```ruby
PM.configure { |c| c.max_include_depth = 3 }
```

## strict_parameters

By default an unknown bare name in a template renders as an empty string. With strict
parameters on, it raises `PM::UnknownParameterError` instead.

```ruby
PM.configure { |c| c.strict_parameters = true }

PM.parse_string('<%= nope %>').to_s
#=> PM::UnknownParameterError: Unknown parameter or directive: nope
```

See [Parameters](../guides/parameters.md#name-resolution) for how names resolve.

## Resetting

Restore every setting to its default and unlock:

```ruby
PM.config.reset!

PM.config.prompts_dir        #=> ''
PM.config.shell              #=> true
PM.config.erb                #=> true
PM.config.max_include_depth  #=> 10
PM.config.strict_parameters? #=> false
PM.config.locked?            #=> false
```

## Accessing Current Settings

```ruby
PM.config.prompts_dir
PM.config.shell
PM.config.erb
PM.config.max_include_depth
PM.config.strict_parameters?
PM.config.locked?
```

## Thread safety

Configuration is process-global and not synchronized. Configure at boot, before
parsing from multiple threads.
