# Installation

## Gemfile

Add PM to your Gemfile:

```ruby
gem 'prompt_manager'
```

Then run:

```bash
bundle install
```

## Manual Install

```bash
gem install prompt_manager
```

## Require

```ruby
require 'pm'
```

The `PM` module is the primary interface. All public methods are accessed through it.

## Requirements

- Ruby >= 3.2.0
- No runtime dependencies beyond the standard library (plus `ostruct` on Ruby 4.0+)
