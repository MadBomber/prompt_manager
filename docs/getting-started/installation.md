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
`require 'prompt_manager'` also works; it loads the same code.

## Requirements

- Ruby >= 4.0.9
- No runtime dependencies. PM uses only the standard library (`yaml`, `erb`, `open3`, `strscan`, `pathname`).
