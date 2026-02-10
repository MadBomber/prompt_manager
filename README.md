# PM (PromptManager)

<table>
<tr>
<td width="50%" align="center" valign="top">
<img src="docs/assets/images/prompt_manager.gif" alt="PromptManager" width="70%"><br>
<em>"Prompts with superpowers"</em>
</td>
<td width="50%" valign="top">
  Like an enchanted librarian enhancing books of knowledge, PromptManager (PM) helps you masterfully orchestrate and organize your AI prompts through wisdom and experience. Each prompt becomes a living entity that can be categorized, parameterized, and interconnected with golden threads of relationships. 

  <h3>Key Features</h3>

- <strong>YAML Metadata</strong> - Parse from markdown strings or files<br>
- <strong>Conditional Shell Expansion</strong> - $ENVAR, ${ENVAR}, $(command) substitution<br>
- <strong>Conditional ERB Templates</strong> - On-demand rendering with named parameters<br>
- <strong>Recursive Include System</strong> - Compose prompts from multiple files<br>
- <strong>Raw File Insert</strong> - Insert any file's content verbatim<br>
- <strong>Custom Directives</strong> - Register custom methods for ERB templates<br>
- <strong>Configurable Pipeline</strong> - Enable/disable stages per prompt or globally<br>
- <strong>Comment Stripping</strong> - HTML comments removed before processing
</td>
</tr>
</table>

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

`PM.parse` accepts a file path, a Symbol, a single word, or a string:

```ruby
# File path (String ending in .md or Pathname)
parsed = PM.parse('code_review.md')
parsed = PM.parse(Pathname.new('code_review.md'))

# Symbol or single word (treated as basename, .md appended)
parsed = PM.parse(:code_review)    #=> parses code_review.md
parsed = PM.parse('code_review')   #=> parses code_review.md

# String content
parsed = PM.parse("---\ntitle: Hello\n---\nContent here")
```

When given a file path, `parse` adds `directory`, `name`, `created_at`, and `modified_at` to the metadata. Both forms run the full processing pipeline.

Note that `PM.parse` treats single words (e.g. `'hello'`) as prompt IDs and appends `.md` to look them up as files. To parse a single word as literal string content, use `PM.parse_string`:

```ruby
PM.parse('hello')              #=> looks for hello.md in prompts_dir
PM.parse_string('hello')       #=> parses "hello" as string content
PM.parse_string('Any string')  #=> always parsed as content, never as a file
```

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

### Inserting raw file content

Use `insert` (or its alias `read`) to insert any file's content verbatim. Unlike `include`, the inserted content is not parsed, shell-expanded, or ERB-rendered — it appears as-is:

```md
---
title: Code Review
parameters:
  feedback_style: null
---
Review this Ruby code:

```ruby
<%= insert 'app/models/user.rb' %>
```

Use a <%= feedback_style %> tone.
```

Paths are resolved relative to the parent file's directory (same as `include`). Absolute paths work from any context. Missing files raise an error.

`insert` vs `include`:

| | `insert` | `include` |
|---|---|---|
| File types | Any | `.md` only |
| ERB in content | Preserved as literal text | Rendered |
| Shell expansion | Not applied | Applied |
| Recursion | None | Nested includes supported |
| Metadata tracking | None | `metadata.includes` tree |

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

#### Block-based registration

Register custom methods available in ERB templates:

```ruby
PM.register(:env)  { |_ctx, key| ENV.fetch(key, '') }
PM.register(:run)  { |_ctx, cmd| `#{cmd}`.chomp }
```

Register multiple names for the same directive (aliases):

```ruby
PM.register(:webpage, :website, :web) { |_ctx, url| fetch_page(url) }
```

#### Class-based directives

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
end

# Register all directive subclasses with PM
PM::Directive.register_all
```

`desc` marks the next method as a directive. Methods without `desc` are helpers and won't be registered. `alias_method` aliases are detected automatically.

Override `build_dispatch_block` on your base class to customize how methods are called:

```ruby
class MyDirectives < PM::Directive
  class << self
    def build_dispatch_block(inst, method_name)
      proc { |_ctx, *args| inst.send(method_name, args) }
    end
  end
end
```

#### RenderContext

The first argument to every directive block (or class method) is a `PM::RenderContext`:

- `ctx.directory` — directory of the file being rendered
- `ctx.params` — merged parameter values
- `ctx.metadata` — the current file's metadata
- `ctx.depth` — include nesting depth
- `ctx.included` — Set of file paths already in the include chain

#### Duplicate detection and reset

Registering a name that already exists raises an error:

```ruby
PM.register(:include) { |_ctx, path| path }
#=> RuntimeError: Directive already registered: include
```

Reset to built-in directives only:

```ruby
PM.reset_directives!
# Restores: include, insert, read
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
