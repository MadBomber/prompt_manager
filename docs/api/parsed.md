# PM::Parsed

The result object returned by `PM.parse` and `PM.parse_string`. An immutable `Data` with two fields: `metadata` and `content`.

## Source

`lib/pm/parsed.rb` (rendering lives in `lib/pm/renderer.rb` and `lib/pm/render_scope.rb`)

## Structure

```ruby
PM::Parsed = Data.define(:metadata, :content)
```

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `metadata` | PM::Metadata | Parsed YAML front matter plus `shell`/`erb` flags and any file-derived keys |
| `content` | String | Content after comment stripping, metadata extraction, and shell expansion |

`Parsed` itself is immutable, but `metadata` is a mutable object: `to_s` writes the
`includes` tree into it.

## Methods

### `[](key)` → Object

Bracket accessor that delegates to `metadata`:

```ruby
parsed = PM.parse("---\ntitle: Hello\n---\nContent")

parsed[:title]    #=> "Hello"
parsed['title']   #=> "Hello"
```

### key?(key) → Boolean

Whether the metadata has the key.

### parameters → Hash

The `parameters` mapping from the front matter, or `{}` when absent.

### to_s(values = {}) → String

Render the prompt content with ERB template evaluation.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `values` | Hash | Parameter values to merge with defaults (String or Symbol keys) |

**Returns:** Rendered prompt as String.

**Raises:** `PM::MissingParameterError` (an `ArgumentError`) if required parameters (those with `nil` defaults) are not provided; `PM::UnknownParameterError` in strict mode for an unknown bare name; the include and shell errors from any directive that runs.

**Behavior:**

1. Resets `metadata.includes` to `[]`
2. If `erb: false`, returns content as-is
3. Merges provided values with parameter defaults from metadata
4. Validates all required parameters are present
5. Evaluates ERB with parameters and registered directives in scope
6. Fills `metadata.includes` with the include tree

```ruby
parsed = PM.parse('review.md')

# With required params
result = parsed.to_s('code' => File.read('app.rb'))

# Override defaults
result = parsed.to_s('code' => source, 'language' => 'python')

# Symbol keys work
result = parsed.to_s(code: source)
```

### to_h → Hash

```ruby
parsed.to_h
#=> { metadata: { title: "Hello", shell: true, erb: true }, content: "Content" }
```

The metadata Hash has Symbol keys.

### to_markdown → String

The prompt as a markdown file again: YAML front matter followed by the content.

```ruby
PM.parse_string("---\ntitle: T\nparameters:\n  a: 1\n---\nBody <%= a %>").to_markdown
#=> "---\ntitle: T\nparameters:\n  a: 1\nshell: true\nerb: true\n---\nBody <%= a %>"
```

- Keys PM derived from the file system (`directory`, `name`, `created_at`, `modified_at`) and the `includes` tree are omitted, so the result re-parses cleanly.
- `shell` and `erb` are always written, because their values were resolved against the global configuration at parse time.
- The content is the parsed content: shell references have already been expanded. ERB is untouched.

### render_with(values, included, depth) → String

Rendering entry point used by the `include` directive, which must pass the active
include chain and depth through.

| Name | Type | Description |
|------|------|-------------|
| `values` | Hash | Merged parameter values |
| `included` | Set | Paths of the ancestor files in the include chain |
| `depth` | Integer | Current include nesting depth |

Not typically called directly.

## Typical Usage

```ruby
parsed = PM.parse('prompt.md')

# Access metadata
parsed.metadata.title
parsed.parameters

# Render
output = parsed.to_s('key' => 'value')

# Check includes after render
parsed.metadata.includes

# Export
File.write('copy.md', parsed.to_markdown)
```
