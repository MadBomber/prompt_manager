# PM::Configuration

Global configuration for PM behavior. Accessed via `PM.config` or `PM.configure`.

## Source

`lib/pm/configuration.rb`

## Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `prompts_dir` | String | `''` | Prepended to relative file paths in `PM.parse` |
| `shell` | Boolean | `true` | Default shell expansion setting for new parses |
| `erb` | Boolean | `true` | Default ERB rendering setting for new parses |
| `max_include_depth` | Integer or nil | `10` | Deepest `include` nesting allowed; `nil` for unlimited |
| `strict_parameters` | Boolean | `false` | Unknown template names raise instead of rendering `""` (reader is `strict_parameters?`) |
| `locked` | Boolean | `false` | Per-file `shell:` / `erb:` are ignored while locked (reader is `locked?`) |

The first four have getters and setters. `strict_parameters` and `locked` have a
setter plus a predicate reader.

## Methods

### initialize

Creates a new Configuration with default values by calling `reset!`.

### reset! → self

Restores all attributes to their defaults and unlocks:

```ruby
PM.config.reset!

PM.config.prompts_dir         #=> ''
PM.config.shell               #=> true
PM.config.erb                 #=> true
PM.config.max_include_depth   #=> 10
PM.config.strict_parameters?  #=> false
PM.config.locked?             #=> false
```

### lock! → self

Freezes the pipeline flags: a file's own `shell:` or `erb:` front matter no longer
overrides the global values.

### unlock! → self

Reverses `lock!`.

### locked? → Boolean

### strict_parameters? → Boolean

## Usage

### Block Configuration

```ruby
PM.configure do |config|
  config.prompts_dir = '~/.prompts'
  config.shell = false
end
```

### Direct Access

```ruby
PM.config.prompts_dir = '/usr/share/prompts'
PM.config.erb = false
```

### Locking

```ruby
PM.configure { |c| c.shell = false }.lock!
```

## Override Behavior

Unlocked (the default): per-file YAML metadata overrides the global setting. If a file has `shell: true` in its front matter, shell expansion runs even when `PM.config.shell` is `false`. The global setting acts as the default when a file does not specify the value.

Locked: the global value is used for every file and the front matter flag is ignored.

## Thread safety

The configuration is a process-global singleton with no synchronization. Set it up
at boot, before parsing or rendering from multiple threads.
