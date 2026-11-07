# PM (PromptManager)

<table>
<tr>
<td width="40%" align="center" valign="top">
<img src="docs/assets/images/prompt_manager.gif" alt="PromptManager" width="100%"><br>
<em>"Prompts with superpowers"</em>
</td>
<td width="60%" valign="top">
<strong>Parse YAML front matter from markdown, expand shell references, compose prompts from other files, and render ERB on demand.</strong><br><br>
PM treats a prompt file as a parameterized template: YAML front matter for metadata and parameters, <code>$VAR</code> / <code>$(command)</code> for environment context, <code>&lt;%= ... %&gt;</code> for rendering, and <code>include</code> / <code>insert</code> for composition.

<h3>Key Features</h3>
<ul>
<li><strong>YAML Metadata</strong> - Parse from markdown strings or files</li>
<li><strong>Shell Expansion</strong> - <code>$VAR</code>, <code>${VAR}</code>, <code>$(command)</code>; <code>\$</code> escapes; code fences are skipped</li>
<li><strong>ERB Templates</strong> - On-demand rendering with required and default parameters</li>
<li><strong>Includes</strong> - Compose prompts from other files, with a tracked include tree</li>
<li><strong>Raw Inserts</strong> - Drop any file in verbatim</li>
<li><strong>Custom Directives</strong> - Blocks or <code>PM::Directive</code> subclasses, callable from ERB</li>
<li><strong>Configurable Pipeline</strong> - Enable, disable, or lock stages globally or per file</li>
<li><strong>Typed Errors</strong> - A <code>PM::Error</code> hierarchy for everything PM raises</li>
<li><strong>Zero runtime dependencies</strong> - Ruby 4.0.9+ and its standard library</li>
</ul>
</td>
</tr>
</table>

Full documentation: <https://madbomber.github.io/prompt_manager>

## Installation

```ruby
# Gemfile
gem 'prompt_manager'
```

```bash
gem install prompt_manager
```

```ruby
require 'pm'
```

Requires Ruby 4.0.9 or later. There are no runtime dependencies.

## Quick start

Given `code_review.md`:

```markdown
---
title: Code Review
model: gpt-4
parameters:
  language: ruby
  code: null
---
Review the following <%= language %> code:

<%= code %>
```

```ruby
parsed = PM.parse('code_review.md')

parsed.metadata.title       #=> "Code Review"
parsed.metadata.model       #=> "gpt-4"
parsed.parameters           #=> {"language" => "ruby", "code" => nil}

parsed.to_s('code' => File.read('app.rb'))
parsed.to_s('code' => File.read('app.py'), 'language' => 'python')

parsed.to_s
#=> PM::MissingParameterError: Missing required parameters: code
```

A parameter whose default is `null` is required. Any other default is optional.

## What `PM.parse` accepts

```ruby
PM.parse('code_review.md')             # String ending in .md  -> file
PM.parse(Pathname.new('review.md'))    # Pathname              -> file
PM.parse(:code_review)                 # Symbol                -> code_review.md
PM.parse('code_review')                # single word           -> code_review.md
PM.parse("---\ntitle: Hi\n---\nBody")  # anything else         -> string content

PM.parse_string('hello')               # always string content, never a file lookup
```

Relative paths are resolved against `PM.config.prompts_dir`. File parses add
`directory`, `name`, `created_at`, and `modified_at` to the metadata.

## Processing pipeline

1. **Strip HTML comments** (`<!-- ... -->`)
2. **Extract YAML front matter** into `PM::Metadata`
3. **Shell expansion** of the content, when `shell: true` (the default)
4. **ERB rendering** when `to_s` is called, when `erb: true` (the default)

Stages 3 and 4 can be turned off per file (`shell: false`, `erb: false`) or
globally (`PM.config.shell = false`). `PM.config.lock!` makes the global values
final so a file cannot turn a stage back on.

## Shell expansion

```markdown
Current user: $USER
Home: ${HOME}
Date: $(date +%Y-%m-%d)
Literal: \$HOME
```

- `$VAR` and `${VAR}` (UPPERCASE names) are replaced with the environment value, or `""` when unset.
- `$(command)` runs via the shell and is replaced with its stdout (trailing newline removed).
- `\$` writes a literal `$`.
- Command output and environment variable values are never re-scanned: a `$VAR`, `$(...)` or `<%= %>` inside them is **not** expanded, run, or evaluated (with ERB on, a `<%` in them is stored as `<%%` and renders as `<%`).
- Fenced code blocks (``` or ~~~) are copied through untouched.
- A failing command raises `PM::ShellCommandError` (with `#command`, `#status`, `#stderr`); an unmatched `$(` raises `PM::ShellExpansionError`.

## Composing prompts

```markdown
---
parameters:
  code: null
---
<%= include 'common/header.md' %>

Review this code:
<%= code %>

<%= insert 'app/models/user.rb' %>
```

| | `include` | `insert` (alias `read`) |
|---|---|---|
| Content is | parsed, shell-expanded, and ERB-rendered | copied verbatim |
| Parameters | parent values passed down | n/a |
| Nesting | yes, up to `PM.config.max_include_depth` (default 10) | none |
| Same file twice | allowed; only a true cycle raises `PM::CircularIncludeError` | allowed |
| Tracked in `metadata.includes` | yes | no |

Paths resolve relative to the including file's directory. `include` needs a file
context and raises `PM::IncludeContextError` from a string-parsed prompt.

## Custom directives

```ruby
PM.register(:env) { |_ctx, key| ENV.fetch(key, '') }
PM.register(:webpage, :website, :web) { |_ctx, url| fetch_page(url) }   # aliases
```

```ruby
class MyDirectives < PM::Directive
  desc "Recent commits"
  def commits(ctx, count = 5)
    `git log --oneline -#{count}`.chomp
  end
  alias_method :log, :commits
end

PM::Directive.register_all
```

Every directive receives a `PM::RenderContext` (`directory`, `params`, `included`,
`depth`, `metadata`) followed by the arguments from the ERB call. Registering a name
that is already taken raises `PM::DirectiveAlreadyRegisteredError`; `PM.register`
registers nothing if any requested name is taken. `PM.reset_directives!` restores
the built-ins (`include`, `insert`, `read`).

Inside a template a bare name resolves to a **parameter** when called without
arguments, then to a **directive**, then to `nil`. Set
`PM.config.strict_parameters = true` to make unknown names raise
`PM::UnknownParameterError` instead.

## Configuration

```ruby
PM.configure do |c|
  c.prompts_dir        = '~/.prompts'  # default ''
  c.shell              = true          # default true
  c.erb                = true          # default true
  c.max_include_depth  = 10            # default 10; nil = unlimited
  c.strict_parameters  = false         # default false
end

PM.config.lock!     # per-file shell:/erb: can no longer override the globals
PM.config.reset!    # back to defaults (also unlocks)
```

## Exporting

```ruby
parsed.to_h          #=> { metadata: {...}, content: "..." }
parsed.to_markdown   #=> front matter + content, re-parseable with PM.parse_string
```

## Errors

Everything PM raises itself descends from `PM::Error`, except parameter errors,
which descend from `ArgumentError` for backward compatibility. Standard-library
errors pass through: `Errno::ENOENT` for a missing file, `Psych::SyntaxError` for
bad YAML, `SyntaxError` for bad ERB. See the
[Errors reference](https://madbomber.github.io/prompt_manager/api/errors/).

## Security model

Prompt files are **code**: ERB can run any Ruby, `$(...)` runs shell commands, and
`include` / `insert` read any path the process can. Only parse files you trust.
Command output, environment variable values, and inserted file contents are inert
(never expanded or evaluated) in ordinary text. A `$VAR` or `$(...)` you write inside
your own ERB tag becomes part of that Ruby code, so keep values you do not control out
of ERB tags. `PM.config.lock!` keeps a file from re-enabling a stage you turned off.
See the [Security guide](https://madbomber.github.io/prompt_manager/guides/security/).

PM is not thread-safe for configuration or directive registration; configure and
register at boot, then parse and render from any thread.

## Development

```bash
bundle install
bundle exec rake test     # runs the suite with a 100% line-coverage gate
```

## License

MIT. See [LICENSE](LICENSE).
