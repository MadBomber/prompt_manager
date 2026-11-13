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

`parameters:` must be a YAML mapping; anything else raises `PM::MetadataError`.

## Required vs Default

- **`null` value** -- the parameter is **required**. `to_s` raises `PM::MissingParameterError` if not provided.
- **Any other value** -- used as the **default**. Can be overridden when calling `to_s`.

```ruby
parsed = PM.parse('code_review.md')

parsed.parameters
#=> {"language" => "ruby", "code" => nil, "style_guide" => "~/guides/default.md"}
```

`parsed.parameters` is a shortcut for `parsed.metadata.parameters` that returns `{}`
when the file declares none.

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

Calling `to_s` without supplying a required parameter raises `PM::MissingParameterError`:

```ruby
parsed.to_s
#=> PM::MissingParameterError: Missing required parameters: code
```

The error message lists all missing parameters. `PM::MissingParameterError` is a
subclass of `ArgumentError`, so code that rescues `ArgumentError` keeps working.

## Name Resolution

Inside a template, a bare identifier is looked up in this order:

1. **A parameter**, when the name is called with no arguments
2. **A directive** (`include`, `insert`, or anything registered with `PM.register`)
3. **`nil`**, which renders as an empty string

```markdown
---
parameters:
  include: "a parameter named include"
---
<%= include %>              <!-- the parameter -->
<%= include 'other.md' %>   <!-- the directive -->
<%= nothing_here %>         <!-- "" -->
```

Calling an unknown name **with** arguments raises `NoMethodError`, as in plain Ruby
(`PM::UnknownParameterError` in strict mode).

### Strict mode

Turn step 3, and the `NoMethodError` above, into `PM::UnknownParameterError`:

```ruby
PM.configure { |c| c.strict_parameters = true }

PM.parse_string('<%= nothing_here %>').to_s
#=> PM::UnknownParameterError: Unknown parameter or directive: nothing_here
```

Strict mode catches typos in parameter names that would otherwise render silently as
empty text.

### Names that collide with Ruby methods

A parameter may be named like a public `Object` method (`display`, `method`, `name`,
`hash`, `format`). It still resolves to the parameter value inside the template. A
handful of names that ERB itself relies on (`class`, `object_id`, `send`, `respond_to?`,
`binding`, `instance_variable_get`, and the other reflection methods) are never shadowed.

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

A child's own `parameters:` defaults apply too; parent values override them.
