# Parameters

Parameters are declared in the YAML `parameters` hash and used as ERB template variables.

## Declaring Parameters

```markdown
---
title: Code Review
parameters:
  language: ruby
  code: null
  style_guide: ~/guides/default.md
---
Review the following <%= language %> code using the style guide
at <%= style_guide %>:

<%= code %>
```

## Required vs Default

- **`null` value** -- the parameter is **required**. `to_s` raises `ArgumentError` if not provided.
- **Any other value** -- used as the **default**. Can be overridden when calling `to_s`.

```ruby
parsed = PM.parse('code_review.md')

parsed.metadata.parameters
#=> {"language" => "ruby", "code" => nil, "style_guide" => "~/guides/default.md"}
```

## Rendering with to_s

`to_s` accepts a Hash of parameter values:

```ruby
# Supply required params, accept defaults for the rest
parsed.to_s('code' => File.read('app.rb'))

# Override a default
parsed.to_s('code' => File.read('app.py'), 'language' => 'python')
```

Symbol keys work too:

```ruby
parsed.to_s(code: File.read('app.rb'))
```

### All Defaults

When every parameter has a default value, `to_s` needs no arguments:

```ruby
parsed.to_s  #=> renders with all defaults
```

### Missing Required Parameters

Calling `to_s` without supplying a required parameter raises `ArgumentError`:

```ruby
parsed.to_s
#=> ArgumentError: Missing required parameters: code
```

The error message lists all missing parameters.

## Parameters in Included Files

When a file includes another file via `<%= include 'child.md' %>`, the parent's parameter values are passed to the child. The child can use the same parameter names:

```markdown
<!-- parent.md -->
---
title: Parent
parameters:
  name: null
---
<%= include 'greeting.md' %>
```

```markdown
<!-- greeting.md -->
---
title: Greeting
---
Hello, <%= name %>!
```

```ruby
parsed = PM.parse('parent.md')
parsed.to_s('name' => 'Alice')
#=> "Hello, Alice!"
```
