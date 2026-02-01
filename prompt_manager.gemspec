# frozen_string_literal: true

require_relative "lib/pm/version"

Gem::Specification.new do |spec|
  spec.name     = "prompt_manager"
  spec.version  = PM::VERSION
  spec.authors  = ["Dewayne VanHoozer"]
  spec.email    = ["dvanhoozer@gmail.com"]

  spec.summary      = "Parse YAML metadata from markdown prompts with shell expansion and ERB rendering"

  spec.description  = <<~EOS
    PM (PromptManager) parses YAML metadata from markdown strings or files.
    It expands shell references, extracts metadata and content, and renders
    ERB templates on demand.
  EOS

  spec.homepage     = "https://github.com/MadBomber/prompt_manager"
  spec.license      = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"]     = spec.homepage
  spec.metadata["source_code_uri"]  = spec.homepage
  spec.metadata["changelog_uri"]    = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
      f.start_with?(*%w[test/ spec/ features/ .git appveyor Gemfile])
    end
  end

  spec.require_paths  = ["lib"]

  spec.add_dependency 'ostruct'

  spec.add_development_dependency 'amazing_print'
  spec.add_development_dependency 'debug_me'
  spec.add_development_dependency "minitest"
  spec.add_development_dependency 'simplecov'
end
