# frozen_string_literal: true

require_relative "lib/prompt_manager/version"

Gem::Specification.new do |spec|
  spec.name     = "prompt_manager"
  spec.version  = PromptManager::VERSION
  spec.authors  = ["Dewayne VanHoozer"]
  spec.email    = ["dvanhoozer@gmail.com"]

  spec.summary      = "Manage prompts for use with gen-AI processes"
  
  spec.description  = <<~EOS
    Manage the parameterized prompts (text) used in generative AI (aka chatGPT, 
    OpenAI, et.al.) using storage adapters such as FileSystemAdapter, 
    SqliteAdapter and ActiveRecordAdapter.
  EOS

  spec.homepage     = "https://github.com/MadBomber/prompt_manager"
  spec.license      = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"]     = spec.homepage
  spec.metadata["source_code_uri"]  = spec.homepage
  spec.metadata["changelog_uri"]    = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end

  spec.bindir         = "bin"
  spec.executables    = []
  spec.require_paths  = ["lib"]

  # TODO: Use these in the Storage Adapters that are TBD
  # spec.add_dependency "activerecord"
  # spec.add_dependency "sqlite3"

  spec.add_development_dependency 'amazing_print'
  spec.add_development_dependency 'debug_me'
  spec.add_development_dependency "minitest"
  spec.add_development_dependency 'tocer'
end
