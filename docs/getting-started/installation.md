# Installation

## System Requirements

PromptManager requires:

- **Ruby**: 2.7 or higher (3.0+ recommended)
- **Operating System**: Linux, macOS, or Windows
- **Dependencies**: No additional system dependencies required

## Install the Gem

### Using Bundler (Recommended)

Add PromptManager to your project's `Gemfile`:

```ruby
# Gemfile
gem 'prompt_manager'
```

Then install:

```bash
bundle install
```

### Using RubyGems

Install directly with gem:

```bash
gem install prompt_manager
```

### Development Installation

For development or to get the latest features:

```bash
git clone https://github.com/MadBomber/prompt_manager.git
cd prompt_manager
bundle install
```

## Verify Installation

Test that PromptManager is installed correctly:

```ruby
require 'prompt_manager'
puts PromptManager::VERSION
```

## Dependencies

PromptManager has minimal dependencies and automatically installs:

- **No external system dependencies**
- **Pure Ruby dependencies** only
- **Lightweight footprint** for easy integration

## Troubleshooting

### Common Issues

!!! warning "Ruby Version"
    
    If you see compatibility errors, ensure you're running Ruby 2.7+:
    
    ```bash
    ruby --version
    ```

!!! tip "Bundler Issues"
    
    If bundle install fails, try updating bundler:
    
    ```bash
    gem update bundler
    bundle install
    ```

### Getting Help

If you encounter installation issues:

1. Check the [GitHub Issues](https://github.com/MadBomber/prompt_manager/issues)
2. Search for similar problems in [Discussions](https://github.com/MadBomber/prompt_manager/discussions)  
3. Create a new issue with:
   - Ruby version (`ruby --version`)
   - Gem version (`gem list prompt_manager`)
   - Error message and full stack trace

## Next Steps

Once installed, continue to the [Quick Start](quick-start.md) guide to begin using PromptManager.