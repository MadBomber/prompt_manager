# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## Unreleased

### Fixed

- **`nil` and empty-directory Pathname `prompts_dir` values work.** `nil` now
  means no prompts directory, like `''`, instead of raising `NoMethodError`.
  A `Pathname` to a directory with no entries was ignored, so relative paths
  resolved against the current directory; it is now prepended. (#32)
- **Expansion output is literal text in templates.** When ERB is enabled, a
  `<%` in the value of a `$VAR` or `${VAR}` is now written as `<%%` and
  renders as a literal `<%`, the same way command output already was, and
  the same applies where an expansion meets the text beside it.
  `PM.expand_shell(str, erb_safe: true)` does the same. If you kept ERB in an
  environment variable on purpose, pass the value as a parameter instead.
- **Directives named like Kernel methods.** A directive registered as
  `format`, `test`, `exec` or another `Kernel` method name is now called from
  a template instead of the method; a bare call still returns a same-named
  parameter. Reserved names such as `to_s`, `tap` and `binding` stay the
  `Object` method.
- **A missing `$(command)` raises a PM error.** A command that cannot be
  started (not found, empty `$()`) now raises `PM::ShellExpansionError`
  with the `SystemCallError` as its `cause`, instead of a bare
  `Errno::ENOENT` that looked like a missing prompt file. (#38)
- **Prompt files are read as UTF-8 under any locale.** `PM.parse` and the
  `insert`/`read` directive no longer fail on non-ASCII text when
  `Encoding.default_external` is not UTF-8 (`LANG=C`). (#37)

### Added

- **`PM::MissingParameterError#names`.** The error now carries the missing
  parameter names as an Array of Strings, so callers no longer have to parse
  the message. The message text is unchanged. (#44)

## [1.2.0] - 2026-11-01

### Fixed

- **Parameters named after private Kernel methods.** A parameter called
  `format`, `test`, `system` or another private `Kernel` method rendered the
  method instead of the value (`<%= format %>` raised `ArgumentError`).
  Parameters now shadow private as well as public `Object` methods. Called
  with arguments or a block (`format('%d', 1)`), the name is still the
  method. `binding` is never shadowed.

## [1.1.0] - 2026-11-01

A hardening release. Shell expansion can no longer be hijacked by its own
output, the include chain works as documented, every failure PM raises has a
class of its own, and the gem ships with zero runtime dependencies at 23 KB
instead of 9.6 MB. No template syntax changed; see **Upgrading** for the
behaviour that did.

### Upgrading from 1.0.x

- **Ruby 4.0.9 or later is required** (was 3.2).
- **Errors are typed.** Failures that raised `RuntimeError` now raise a
  `PM::Error` subclass (`PM::CircularIncludeError`, `PM::ShellCommandError`,
  `PM::FileNotFoundError`, ...). `rescue RuntimeError` no longer catches them;
  `rescue PM::Error` does. Missing-parameter errors are still `ArgumentError`s
  with the same message, via `PM::MissingParameterError`.
- **Two silent cases now raise:** an unmatched `$(` (`PM::ShellExpansionError`)
  and a `shell:` / `erb:` value that is not a boolean or true/false/yes/no/on/off
  (`PM::MetadataError`).
- **`PM::Metadata` is no longer an `OpenStruct`.** Dot access, predicates, `[]`,
  `respond_to?`, and `to_h` are unchanged; only `is_a?(OpenStruct)` checks break.
- **`PM::Parsed` and `PM::RenderContext` are immutable `Data` objects.** Readers
  are unchanged; writers such as `parsed.content = ...` are gone.
- **`PM.directives` returns a frozen snapshot.** Use `PM.register` and
  `PM.reset_directives!` to change the registry.
- **The gem no longer contains `docs/`, examples, or media.** Documentation is
  at <https://madbomber.github.io/prompt_manager>.

### Added

- **Error hierarchy** rooted at `PM::Error`: `MetadataError`,
  `ShellExpansionError` > `ShellCommandError` (`#command`, `#status`, `#stderr`),
  `IncludeError` > `CircularIncludeError` / `IncludeDepthError` /
  `IncludeContextError`, `FileNotFoundError`, `DirectiveAlreadyRegisteredError`;
  plus `ParameterError` > `MissingParameterError` / `UnknownParameterError`
  under `ArgumentError`.
- **Configuration:** `lock!` / `unlock!` / `locked?` make the global `shell` and
  `erb` final so a file cannot re-enable a stage; `max_include_depth` (default 10,
  `nil` = unlimited); `strict_parameters` turns an unknown template name into
  `PM::UnknownParameterError` instead of `""`. `PM.configure` returns the config.
- **Shell expansion:** `\$` writes a literal `$`; fenced code blocks (``` / ~~~)
  are skipped; `PM.expand_shell(str, erb_safe: true)` escapes `<%` in command output.
- **`PM::Parsed`:** `#to_h`, `#to_markdown` (round-trippable front matter +
  content, derived keys omitted), `#parameters`, `#key?`.
- **`PM::Metadata`:** `Enumerable`, plus `dig`, `fetch`, `keys`, `values`,
  `size`, `empty?`, `delete`, `each_pair`, `==`.
- **`PM.directive?(name)`.**
- **CI:** GitHub Actions on Ubuntu and macOS with a 100% line-coverage gate
  (SimpleCov); `.ruby-version` pins development to 4.0.9.
- **Docs:** new Security guide and Errors reference.

### Changed

- **Shell expansion is one left-to-right pass.** Command output is spliced in
  verbatim and never re-scanned, so `$VAR`, `$(...)`, or `<%` printed by a
  command stays text. Command stderr goes to `$stderr` on success and into
  `ShellCommandError` on failure.
- **`include` tracks ancestors, not every rendered file,** so the same fragment
  can be included twice in one prompt. Included files may have any extension.
- **Front matter is validated:** must be a mapping (or empty); `parameters:`
  must be a mapping; flags are coerced as described under Upgrading.
- **Directive registry policy:** `PM.register` is atomic (nothing is registered
  if any name is taken). `PM::Directive.register_all` is idempotent, lets a later
  subclass override an earlier one, and raises if a name was claimed with
  `PM.register`.
- **Template name resolution is defined:** parameter (called without arguments)
  > directive > `nil` (or error in strict mode).
- **Internals:** rendering moved from `Parsed` into `PM::Renderer` and
  `PM::RenderScope`; `Parsed#render_with` remains for `include`.
- **Packaging:** gemspec allow-lists `lib/**/*.rb`, `README.md`, `CHANGELOG.md`,
  `LICENSE`; adds `changelog_uri`, `documentation_uri`, `bug_tracker_uri`;
  development dependencies move to the Gemfile.

### Fixed

- Including the same file twice raised "Circular include detected".
- Empty (`---\n---`) or scalar front matter raised `NoMethodError`.
- `include` of a path without `.md` parsed the path string as the prompt.
- `created_at` raised `NotImplementedError` on filesystems without birthtime;
  it now falls back to `ctime`.
- `erb: 'true'` (a string) silently disabled ERB.
- A metadata key named like an `Object` method (`hash`, `method`, `display`)
  returned the method instead of the value.
- Two tests asserted nothing and produced `ruby -w` warnings; `.irbrc` used the
  removed 0.x API.
- Documentation corrections throughout: built-in directive lists, error messages,
  `content` newline examples, `Struct` signatures, hard-coded version, an opening
  example that registered the built-in `:read`, and fences nested inside fences.

### Removed

- The `ostruct` runtime dependency. PM now has none.
- `test/pm_test.rb` (redundant with the Rakefile glob).
- Documentation, examples, and media from the packaged gem.

## [1.0.2] - 2026-02-09

### Changed
- Made `PM.parse_string` a public class method so it can be called directly for parsing strings without file-based metadata enrichment.

## [1.0.1] - 2026-02-04

### Added
- **`PM::Directive` base class** — class-based DSL for defining directive categories. Use `desc` before method definitions to mark them as directives, and `alias_method` for aliases. Subclass tracking, `register_all`, `category_name`, and `build_dispatch_block` are all built-in.
- **Built-in `insert` directive** (alias: `read`) — insert any file's raw content into a prompt. Unlike `include`, the inserted content is not parsed, shell-expanded, or ERB-rendered.
- New test file `directive_base_test.rb` with tests for the `PM::Directive` DSL, subclass tracking, category naming, and dispatch block building.
- New test fixtures for `insert`/`read` directive coverage.

### Changed
- **`PM::CoreDirectives`** — built-in `include`, `insert`/`read` directives refactored as a `PM::Directive` subclass using the `desc` DSL.
- `PM.register` directive aliases now support registration via `alias_method` in `PM::Directive` subclasses, with automatic detection via `UnboundMethod#original_name`.
- Directive registry simplified; `PM.reset_directives!` now delegates to `PM::Directive.register_all`.
- Updated README and documentation guides for custom directives and includes.

## [1.0.0] - 2026-02-03

**Complete rewrite** — repositioned from a prompt management system with storage adapters to a focused prompt parsing and rendering engine.

### Breaking Changes
- **New `PM` module replaces `PromptManager`** — the entire codebase has been restructured under the `PM` namespace. A backward-compatibility alias (`PromptManager = PM`) is provided via `require 'prompt_manager'`.
- **Storage adapters removed** — `FileSystemAdapter`, `ActiveRecordAdapter`, and all database-backed persistence have been removed. The library now operates on strings, files, and Pathnames directly.
- **`Prompt` class removed** — replaced by the lightweight `PM::Parsed` struct.
- **`DirectiveProcessor` class removed** — replaced by a simple `PM.register` directive registration API.
- **Parameter history removed** — the library no longer tracks historical parameter values per keyword.
- **Configuration simplified** — only three settings remain: `prompts_dir`, `shell`, and `erb`. Options like `parameter_regex` and `search_proc` have been removed.

### New Features
- **Symbol and single-word parsing** — `PM.parse(:code_review)` and `PM.parse('code_review')` automatically resolve to `code_review.md` in the configured `prompts_dir`.
- **Directive aliases** — `PM.register(:webpage, :website, :web) { |ctx, url| ... }` registers multiple names for a single directive with rollback on duplicate detection.
- **`PM::Metadata`** — OpenStruct-based metadata with automatic predicate methods for boolean fields (e.g., `metadata.shell?`).
- **`PM::Parsed`** — Struct-based result with `RenderContext` support and required-parameter validation in `to_s`.
- **Built-in `include` directive** — compose prompts from multiple files with loop protection.
- **Streamlined parsing pipeline** — strip HTML comments, extract YAML front matter, optional shell expansion (`$VAR`, `${VAR}`, `$(command)`), optional ERB rendering.

### Removed
- `PromptManager::Prompt` class
- `PromptManager::DirectiveProcessor` class
- `PromptManager::Storage::FileSystemAdapter`
- `PromptManager::Storage::ActiveRecordAdapter`
- Custom error classes (`PromptManager::Error` hierarchy)
- Development dependencies on `activerecord`, `sqlite3`, and `tocer`

### Added
- Runtime dependency on `ostruct`
- Comprehensive test suite (8 test files, 19 fixtures)
- Full documentation site under `docs/` with guides for parsing, shell expansion, ERB rendering, custom directives, and prompt composition

## [0.5.8] - 2025-09-01
- fixed issue where removed keywords from prompt text were still being included in parameters if they existed in the JSON file (addresses AIA issue #105)
- parameters now only include keywords currently present in the prompt text, while preserving historical values for existing keywords

## [0.5.7] - 2025-06-25
- fixed a problem when the value of a parameter is an empty array
- fixed a failing test

## [0.5.6] - 2025-06-04
- fixed a problem where shell integration was not working correctly for $(shell command)

## [0.5.5] - 2025-05-21
- fixed bug in parameter substitution when value is an Array now uses last entry

## [0.5.4] - 2025-05-18
- fixed typo in the Prompt class envvar should have been envar which prevented shell integration from taking place.

## [0.5.3] - 2025-05-14
- fixed issue were directives were not getting their content added to the prompt text
- Updated documentation and versioning.
- Added new error classes for better error handling.
- Improved parameter handling and directive processing.

## [0.5.2] - 2025-04-18
- Made comment removal in `Prompt` markdown-aware so fenced ```markdown blocks are preserved and HTML comments are stripped.

## [0.5.1] - 2025-04-14
- Fixed parameter handling in the file system adapter so parameters are parsed from the prompt text and merged with values stored on disk (ref issue #14 / PR #15).

## [0.5.0] - 2025-03-29
- Major refactoring of to improve processing of parameters and directives.
- Added PromptManager::DirectiveProcessor as an example of how to implement custom directives.
- Added support for //include directive that protects against loops.
- Added support for embedding system environment variables.
- Added support for ERB processing within a prompt.
- Improved test coverage.

## [0.4.2] - 2024-10-26
- Added configurable parameter_regex to customize keyword pattern

## [0.4.1] - 2023-12-29
- Changed @directives from Hash to an Array
- Fixed keywords not being substituted in directives

## [0.4.0] - 2023-12-19
- Add "//directives param(s)" with keywords just like the prompt text.

## [0.3.3] - 2023-12-01
- Added example of using the `search_proc` config parameter with the FileSystemAdapter.

## [0.3.2] - 2023-12-01

- The ActiveRecordAdapter is passing its unit tests
- Dropped the concept of an sqlite3 adapter since active record can be used to access sqlite3 databases as well as the big boys.

## [0.3.0] - 2023-11-28

- **Breaking change** The value of the parameters Hash for a keyword is now an Array instead of a single value.  The last value in the Array is always the most recent value used for the given keyword.  This was done to support the use of a Readline::History object editing in the [aia](https://github.com/MadBomber/aia) CLI tool

## [0.2.0] - 2023-11-21

- **Breaking change to FileSystemAdapter config process**
- added list and path as extra methods in FileSystemAdapter

## [0.1.0] - 2023-11-16

- Initial release using the FileSystemAdapter
