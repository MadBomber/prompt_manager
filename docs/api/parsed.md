# PM::Parsed

The result object returned by `PM.parse`. A Struct with two fields: `metadata` and `content`.

## Source

`lib/pm/parsed.rb`

## Structure

```ruby
PM::Parsed = Struct.new(:metadata, :content)
```

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `metadata` | PM::Metadata | Parsed YAML front-matter |
| `content` | String | Markdown content after metadata extraction and shell expansion |

## Methods

### `[](key)` → Object

Bracket accessor that delegates to `metadata`:

```ruby
parsed = PM.parse("---\ntitle: Hello\n---\nContent")

parsed[:title]    #=> "Hello"
parsed['title']   #=> "Hello"
```

### to_s(values = {}) → String

Render the prompt content with ERB template evaluation.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `values` | Hash | Parameter values to merge with defaults |

**Returns:** Rendered prompt as String.

**Raises:** `ArgumentError` if required parameters (those with `nil` defaults) are not provided.

**Behavior:**

1. Merges provided values with parameter defaults from metadata
2. Validates all required parameters are present
3. If `erb: true`, evaluates ERB with parameters and registered directives
4. If `erb: false`, returns content as-is
5. Populates `metadata.includes` with the include tree

```ruby
parsed = PM.parse('review.md')

# With required params
result = parsed.to_s('code' => File.read('app.rb'))

# Override defaults
result = parsed.to_s('code' => source, 'language' => 'python')

# Symbol keys work
result = parsed.to_s(code: source)
```

### render_with(values, included, depth) → String

Internal method used by `to_s` and the `include` directive. Handles the ERB rendering pipeline with include tracking.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `values` | Hash | Merged parameter values |
| `included` | Set | File paths already in the include chain |
| `depth` | Integer | Current include nesting depth |

This method is not typically called directly.

## Typical Usage

```ruby
parsed = PM.parse('prompt.md')

# Access metadata
parsed.metadata.title
parsed.metadata.parameters

# Render
output = parsed.to_s('key' => 'value')

# Check includes after render
parsed.metadata.includes
```
