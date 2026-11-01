# frozen_string_literal: true

require_relative "lib/pm/version"

Gem::Specification.new do |spec|
  spec.name     = "prompt_manager"
  spec.version  = PM::VERSION
  spec.authors  = ["Dewayne VanHoozer"]
  spec.email    = ["dvanhoozer@gmail.com"]

  spec.summary      = "Parse YAML metadata from markdown prompts with shell expansion and ERB rendering"

  spec.description  = <<~EOS
    PM (PromptManager) parses YAML front matter from markdown strings or files.
    It expands shell references, extracts metadata and content, composes prompts
    from other files with include/insert directives, and renders ERB on demand.
  EOS

  spec.homepage     = "https://github.com/MadBomber/prompt_manager"
  spec.license      = "MIT"

  spec.required_ruby_version = ">= 4.0.9"

  spec.metadata["allowed_push_host"]  = "https://rubygems.org"
  spec.metadata["homepage_uri"]       = spec.homepage
  spec.metadata["source_code_uri"]    = spec.homepage
  spec.metadata["changelog_uri"]      = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"]  = "https://madbomber.github.io/prompt_manager"
  spec.metadata["bug_tracker_uri"]    = "#{spec.homepage}/issues"

  # Allow-list: the library and the three files rubygems.org shows. Docs,
  # site assets, and development files stay out of the package.
  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*.rb"] + %w[README.md CHANGELOG.md LICENSE]
  end

  spec.require_paths = ["lib"]

  # No runtime dependencies: everything used ships with Ruby.
end
