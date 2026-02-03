# Configuration

PM has three global settings controlled through `PM.configure`.

## Setting Defaults

```ruby
PM.configure do |config|
  config.prompts_dir = '~/.prompts'   # default: ''
  config.shell       = true           # default: true
  config.erb         = true           # default: true
end
```

## prompts_dir

Prepended to relative file paths passed to `PM.parse`. Absolute paths bypass it. Symbols and single words are converted to `.md` basenames first.

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

Per-file YAML metadata overrides the global setting:

```markdown
---
title: Override Example
shell: true
---
This file gets shell expansion even when the global default is false.
User: $USER
```

## erb

Controls whether ERB rendering runs during `to_s`. Defaults to `true`.

```ruby
PM.configure { |c| c.erb = false }

# All files now skip ERB rendering by default
```

Per-file metadata overrides this too:

```markdown
---
title: Override Example
erb: true
---
This file renders ERB even when the global default is false.
Result: <%= 2 + 2 %>
```

## Resetting

Restore all settings to their defaults:

```ruby
PM.config.reset!

PM.config.prompts_dir  #=> ''
PM.config.shell        #=> true
PM.config.erb          #=> true
```

## Accessing Current Settings

```ruby
PM.config.prompts_dir
PM.config.shell
PM.config.erb
```

`PM.config` returns the singleton `PM::Configuration` instance. `PM.configure` yields the same instance.
