# PM (PromptManager)

PM (PromptManager) parses YAML metadata from markdown strings or files. It expands shell references, extracts metadata and content, and renders ERB templates on demand.

## Installation

```ruby
require 'pm'
```

## Configuration

Set global defaults with `PM.configure`:

```ruby
PM.configure do |config|
  config.prompts_dir = '~/.prompts'   # default: ''
  config.shell       = true           # default: true
  config.erb         = true           # default: true
end
```

**`prompts_dir`** is prepended to relative file paths passed to `PM.parse`. Absolute paths bypass it:

```ruby
PM.configure { |c| c.prompts_dir = '/usr/share/prompts' }

PM.parse('code_review.md')
#=> reads /usr/share/prompts/code_review.md

PM.parse('/absolute/path/review.md')
#=> reads /absolute/path/review.md (prompts_dir ignored)
```

**`shell`** and **`erb`** set the global defaults for new parses. Per-file YAML metadata overrides the global setting:

```ruby
PM.configure { |c| c.shell = false }

# All files now default to shell: false
# A file with "shell: true" in its YAML still gets shell expansion
```

Reset all settings to defaults:

```ruby
PM.config.reset!
```

Access the current configuration:

```ruby
PM.config.prompts_dir  #=> ''
PM.config.shell        #=> true
PM.config.erb          #=> true
```

## Usage

`PM.parse` accepts a file path or a string:

```ruby
# File path (String ending in .md or Pathname)
parsed = PM.parse('code_review.md')
parsed = PM.parse(Pathname.new('code_review.md'))

# String content
parsed = PM.parse("---\ntitle: Hello\n---\nContent here")
```

When given a file path, `parse` adds `directory`, `name`, `created_at`, and `modified_at` to the metadata. Both forms run the full processing pipeline.

Given a file `code_review.md`:

```md
---
title: Code Review
provider: openai
model: gpt-4
temperature: 0.3
parameters:
  language: ruby
  code: null
  style_guide: ~/guides/default.md
---
Review the following <%= language %> code using the style guide
at <%= style_guide %>:

<%= code %>
```

Parse it:

```ruby
parsed = PM.parse('code_review.md')
parsed.metadata.parameters
#=> {'language' => 'ruby', 'code' => nil, 'style_guide' => '~/guides/default.md'}
```

Build the prompt with `to_s`:

```ruby
# Provide required params, accept defaults for the rest
parsed.to_s('code' => File.read('app.rb'))

# Override defaults
parsed.to_s('code' => File.read('app.py'), 'language' => 'python')

# All params have defaults — no arguments needed
parsed.to_s

# Missing a required parameter raises an error
parsed.to_s
#=> ArgumentError: Missing required parameters: code
```

Parameters with a `null` default in the YAML are required. Parameters with any other default are optional.

### Shell expansion

Shell references are expanded during parsing (when `shell: true`, the default):

```md
---
title: Deploy Check
parameters:
  environment: null
---
Current user: $USER
Home directory: ${HOME}
Date: $(date +%Y-%m-%d)
Git branch: $(git rev-parse --abbrev-ref HEAD)
Deploy to: <%= environment %>
```

- `$ENVAR` and `${ENVAR}` are replaced with the environment variable's value.
- `$(command)` is executed and replaced with its stdout.
- Missing environment variables are replaced with an empty string.
- Failed commands raise an error.

Shell expansion is also available directly:

```ruby
PM.expand_shell(string)
```

### Including other prompt files

Use `include` in ERB to compose prompts from multiple files:

```md
---
title: Full Review
parameters:
  code: null
---
<%= include 'common/header.md' %>

Review this code:
<%= code %>

<%= include 'common/footer.md' %>
```

Included files go through the full processing pipeline (comment stripping, metadata extraction, shell expansion, ERB rendering). The parent's parameter values are passed to included files.

Nested includes work — A can include B which includes C. Circular includes raise an error.

After calling `to_s`, the parent's metadata has an `includes` key with a tree of what was included:

```ruby
parsed = PM.parse('full_review.md')
parsed.to_s('code' => File.read('app.rb'))

parsed.metadata.includes
#=> [
#     {
#       path:     "/prompts/common/header.md",
#       depth:    1,
#       metadata: { title: "Header", ... },
#       includes: []
#     },
#     {
#       path:     "/prompts/common/footer.md",
#       depth:    1,
#       metadata: { title: "Footer", ... },
#       includes: []
#     }
#   ]
```

### Custom directives

Register custom methods available in ERB templates:

```ruby
PM.register(:read) { |_ctx, path| File.read(path) }
PM.register(:env)  { |_ctx, key| ENV.fetch(key, '') }
PM.register(:run)  { |_ctx, cmd| `#{cmd}`.chomp }
```

Use them in any prompt file:

```md
---
title: Deploy Prompt
---
Hostname: <%= read '/etc/hostname' %>
Environment: <%= env 'DEPLOY_ENV' %>
Recent commits: <%= run 'git log --oneline -5' %>
```

The first argument to every directive block is a `PM::RenderContext` with access to the current render state:

- `ctx.directory` — directory of the file being rendered
- `ctx.params` — merged parameter values
- `ctx.metadata` — the current file's metadata
- `ctx.depth` — include nesting depth
- `ctx.included` — Set of file paths already in the include chain

```ruby
PM.register(:current_file) { |ctx| ctx.metadata.name || 'unknown' }
PM.register(:depth) { |ctx| ctx.depth.to_s }
```

Registering a name that already exists raises an error:

```ruby
PM.register(:include) { |_ctx, path| path }
#=> RuntimeError: Directive already registered: include
```

Reset to built-in directives only:

```ruby
PM.reset_directives!
```

### Disabling processing stages

Set `shell: false` or `erb: false` in the metadata to skip those stages:

```md
---
title: Raw Template
shell: false
erb: false
---
This $USER and <%= name %> content is preserved as-is.
```

Both default to `true` when not specified. You can change these defaults globally via `PM.configure` (see [Configuration](#configuration)). Per-file metadata always overrides the global setting.

### HTML comment stripping

HTML comments are stripped before any other processing:

```md
<!-- This comment will be removed -->
---
title: My Prompt
---
Content here. <!-- This too -->
```

Comments are also available directly:

```ruby
PM.strip_comments(string)
```

## Processing pipeline

1. Strip HTML comments
2. Extract YAML metadata and markdown content
3. Shell expansion (`$ENVAR`, `$(command)`) when `shell: true`
4. ERB rendering on demand via `to_s` when `erb: true`
