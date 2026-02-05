### [1.0.1] - 2026-02-04

#### Added
- **`PM::Directive` base class** — class-based DSL for defining directive categories. Use `desc` before method definitions to mark them as directives, and `alias_method` for aliases. Subclass tracking, `register_all`, `category_name`, and `build_dispatch_block` are all built-in.
- **Built-in `insert` directive** (alias: `read`) — insert any file's raw content into a prompt. Unlike `include`, the inserted content is not parsed, shell-expanded, or ERB-rendered.
- New test file `directive_base_test.rb` with tests for the `PM::Directive` DSL, subclass tracking, category naming, and dispatch block building.
- New test fixtures for `insert`/`read` directive coverage.

#### Changed
- **`PM::CoreDirectives`** — built-in `include`, `insert`/`read` directives refactored as a `PM::Directive` subclass using the `desc` DSL.
- `PM.register` directive aliases now support registration via `alias_method` in `PM::Directive` subclasses, with automatic detection via `UnboundMethod#original_name`.
- Directive registry simplified; `PM.reset_directives!` now delegates to `PM::Directive.register_all`.
- Updated README and documentation guides for custom directives and includes.

## Released
### [1.0.0] = 2026-02-03

**Complete rewrite** — repositioned from a prompt management system with storage adapters to a focused prompt parsing and rendering engine.

#### Breaking Changes
- **New `PM` module replaces `PromptManager`** — the entire codebase has been restructured under the `PM` namespace. A backward-compatibility alias (`PromptManager = PM`) is provided via `require 'prompt_manager'`.
- **Storage adapters removed** — `FileSystemAdapter`, `ActiveRecordAdapter`, and all database-backed persistence have been removed. The library now operates on strings, files, and Pathnames directly.
- **`Prompt` class removed** — replaced by the lightweight `PM::Parsed` struct.
- **`DirectiveProcessor` class removed** — replaced by a simple `PM.register` directive registration API.
- **Parameter history removed** — the library no longer tracks historical parameter values per keyword.
- **Configuration simplified** — only three settings remain: `prompts_dir`, `shell`, and `erb`. Options like `parameter_regex` and `search_proc` have been removed.

#### New Features
- **Symbol and single-word parsing** — `PM.parse(:code_review)` and `PM.parse('code_review')` automatically resolve to `code_review.md` in the configured `prompts_dir`.
- **Directive aliases** — `PM.register(:webpage, :website, :web) { |ctx, url| ... }` registers multiple names for a single directive with rollback on duplicate detection.
- **`PM::Metadata`** — OpenStruct-based metadata with automatic predicate methods for boolean fields (e.g., `metadata.shell?`).
- **`PM::Parsed`** — Struct-based result with `RenderContext` support and required-parameter validation in `to_s`.
- **Built-in `include` directive** — compose prompts from multiple files with loop protection.
- **Streamlined parsing pipeline** — strip HTML comments, extract YAML front matter, optional shell expansion (`$VAR`, `${VAR}`, `$(command)`), optional ERB rendering.

#### Removed
- `PromptManager::Prompt` class
- `PromptManager::DirectiveProcessor` class
- `PromptManager::Storage::FileSystemAdapter`
- `PromptManager::Storage::ActiveRecordAdapter`
- Custom error classes (`PromptManager::Error` hierarchy)
- Development dependencies on `activerecord`, `sqlite3`, and `tocer`

#### Added
- Runtime dependency on `ostruct`
- Comprehensive test suite (8 test files, 19 fixtures)
- Full documentation site under `docs/` with guides for parsing, shell expansion, ERB rendering, custom directives, and prompt composition

### [0.5.8] = 2025-09-01
- fixed issue where removed keywords from prompt text were still being included in parameters if they existed in the JSON file (addresses AIA issue #105)
- parameters now only include keywords currently present in the prompt text, while preserving historical values for existing keywords

### [0.5.7] = 2025-06-25
- fixed a problem when the value of a parameter is an empty array
- fixed a failing test

### [0.5.6] = 2025-06-04
- fixed a problem where shell integration was not working correctly for $(shell command)

### [0.5.5] = 2025-05-21
- fixed bug in parameter substitution when value is an Array now uses last entry

### [0.5.4] = 2025-05-18
- fixed typo in the Prompt class envvar should have been envar which prevented shell integration from taking place.

### [0.5.3] = 2025-05-14
- fixed issue were directives were not getting their content added to the prompt text
- Updated documentation and versioning.
- Added new error classes for better error handling.
- Improved parameter handling and directive processing.

### [0.5.0] = 2025-03-29
- Major refactoring of to improve processing of parameters and directives.
- Added PromptManager::DirectiveProcessor as an example of how to implement custom directives.
- Added support for //include directive that protects against loops.
- Added support for embedding system environment variables.
- Added support for ERB processing within a prompt.
- Improved test coverage.

### [0.4.2] = 2024-10-26
- Added configurable parameter_regex to customize keyword pattern

### [0.4.1] = 2023-12-29
- Changed @directives from Hash to an Array
- Fixed keywords not being substituted in directives

### [0.4.0] = 2023-12-19
- Add "//directives param(s)" with keywords just like the prompt text.

### [0.3.3] = 2023-12-01
- Added example of using the `search_proc` config parameter with the FileSystemAdapter.

### [0.3.2] = 2023-12-01

- The ActiveRecordAdapter is passing its unit tests
- Dropped the concept of an sqlite3 adapter since active record can be used to access sqlite3 databases as well as the big boys.

### [0.3.0] = 2023-11-28

- **Breaking change** The value of the parameters Hash for a keyword is now an Array instead of a single value.  The last value in the Array is always the most recent value used for the given keyword.  This was done to support the use of a Readline::History object editing in the [aia](https://github.com/MadBomber/aia) CLI tool

### [0.2.0] - 2023-11-21

- **Breaking change to FileSystemAdapter config process**
- added list and path as extra methods in FileSystemAdapter

### [0.1.0] - 2023-11-16

- Initial release using the FileSystemAdapter
