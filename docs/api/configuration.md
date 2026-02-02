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

All attributes have both getter and setter methods (`attr_accessor`).

## Methods

### initialize

Creates a new Configuration with default values by calling `reset!`.

### reset! → nil

Restores all attributes to their defaults:

```ruby
PM.config.reset!

PM.config.prompts_dir  #=> ''
PM.config.shell        #=> true
PM.config.erb          #=> true
```

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

## Override Behavior

Per-file YAML metadata always overrides the global setting. If a file has `shell: true` in its front-matter, shell expansion runs even when `PM.config.shell` is `false`.

The global setting acts as the default when a file does not specify the value.
