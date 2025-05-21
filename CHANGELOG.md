## Unreleased

## Released
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
