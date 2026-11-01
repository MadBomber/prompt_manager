# PM::RenderContext

Context object passed as the first argument to every directive block during ERB rendering.

## Source

`lib/pm/parsed.rb`

## Structure

```ruby
PM::RenderContext = Data.define(:directory, :params, :included, :depth, :metadata)
```

It is an immutable `Data` with keyword construction and a default for every field:

```ruby
PM::RenderContext.new
#=> #<data PM::RenderContext directory=nil, params={}, included=Set[], depth=0, metadata=nil>

PM::RenderContext.new(directory: '/prompts', params: { 'name' => 'Alice' })
```

## Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `directory` | String or nil | `nil` | Absolute path to the directory of the file being rendered; `nil` for string-parsed prompts |
| `params` | Hash | `{}` | Merged parameter values (defaults + overrides), String keys |
| `included` | Set | `Set.new` | Paths of the ancestor files in the include chain (for circular detection) |
| `depth` | Integer | `0` | Include nesting depth (0 for the top-level file) |
| `metadata` | PM::Metadata or nil | `nil` | Metadata of the file being rendered |

## Usage in Directives

Every directive block receives a RenderContext as its first argument:

```ruby
PM.register(:current_file) { |ctx| ctx.metadata.name || 'unknown' }

PM.register(:nesting) { |ctx| ctx.depth.to_s }

PM.register(:sibling) do |ctx, filename|
  File.read(File.join(ctx.directory, filename))
end

PM.register(:param_dump) do |ctx|
  ctx.params.map { |k, v| "#{k}: #{v}" }.join(', ')
end
```

## Context During Includes

When a file is included, the RenderContext reflects the included file's state:

- `directory` is the included file's directory
- `metadata` is the included file's metadata
- `depth` increments by 1 for each nesting level
- `included` contains the ancestor file paths, including the current file
- `params` carries the parent's merged parameter values

Because `included` holds only the ancestors (not every file rendered so far), the
same file can be included twice by siblings without tripping circular detection.
