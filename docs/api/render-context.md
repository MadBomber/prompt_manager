# PM::RenderContext

Context object passed as the first argument to every directive block during ERB rendering.

## Source

`lib/pm/parsed.rb`

## Structure

```ruby
PM::RenderContext = Struct.new(:directory, :params, :included, :depth, :metadata)
```

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `directory` | String | Absolute path to the directory of the file being rendered |
| `params` | Hash | Merged parameter values (defaults + overrides) |
| `included` | Set | File paths already in the include chain (for circular detection) |
| `depth` | Integer | Include nesting depth (0 for top-level file) |
| `metadata` | PM::Metadata | Metadata of the file being rendered |

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
- `included` contains all ancestor file paths
- `params` carries the parent's merged parameter values
