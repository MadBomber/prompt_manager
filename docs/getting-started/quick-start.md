# Quick Start

## Parse a String

```ruby
require 'pm'

parsed = PM.parse("---\ntitle: Hello\n---\nContent here")

parsed.metadata.title  #=> "Hello"
parsed.content         #=> "\nContent here\n"
```

## Parse a File

Given `greeting.md`:

```markdown
---
title: Greeting
parameters:
  name: null
---
Hello, <%= name %>! Welcome.
```

```ruby
parsed = PM.parse('greeting.md')

parsed.metadata.title       #=> "Greeting"
parsed.metadata.parameters  #=> {"name" => nil}

# Render with parameters
puts parsed.to_s('name' => 'Alice')
#=> "Hello, Alice! Welcome."
```

When parsing a file, PM also adds `directory`, `name`, `created_at`, and `modified_at` to the metadata.

## Parameters

Parameters declared in the YAML front-matter define template variables:

- **`null` value** -- parameter is required; `to_s` raises `ArgumentError` if missing
- **Any other value** -- used as the default; can be overridden in `to_s`

```ruby
parsed = PM.parse("---\nparameters:\n  lang: ruby\n  code: null\n---\n<%= lang %>: <%= code %>")

# Use defaults where available, supply required params
parsed.to_s('code' => 'puts "hi"')  #=> "ruby: puts \"hi\""

# Override defaults
parsed.to_s('code' => 'print("hi")', 'lang' => 'python')
```

## Shell Expansion

Environment variables and commands are expanded at parse time:

```markdown
---
title: Info
---
User: $USER
Date: $(date +%Y-%m-%d)
```

```ruby
parsed = PM.parse('info.md')
parsed.content  #=> "User: dewayne\nDate: 2025-01-15\n"
```

## Next Steps

- [Configuration](configuration.md) -- Set a prompts directory and global defaults
- [Parsing Guide](../guides/parsing.md) -- File vs string parsing in depth
- [Parameters Guide](../guides/parameters.md) -- Required and default parameters
