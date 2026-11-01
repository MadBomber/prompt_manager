# Errors

Everything PM raises itself is a subclass of `PM::Error`, except the parameter
errors, which subclass `ArgumentError` so that code written against 1.0.x
(`rescue ArgumentError`) keeps working.

## Source

`lib/pm/errors.rb`

## Hierarchy

```
StandardError
├── PM::Error
│   ├── PM::MetadataError
│   ├── PM::ShellExpansionError
│   │   └── PM::ShellCommandError          #command, #status, #stderr
│   ├── PM::IncludeError
│   │   ├── PM::CircularIncludeError
│   │   ├── PM::IncludeDepthError
│   │   └── PM::IncludeContextError
│   ├── PM::FileNotFoundError
│   └── PM::DirectiveAlreadyRegisteredError
└── ArgumentError
    └── PM::ParameterError
        ├── PM::MissingParameterError
        └── PM::UnknownParameterError
```

## When each is raised

| Error | Raised by | When |
|---|---|---|
| `MetadataError` | `PM.parse`, `PM.parse_string` | Front matter is not a YAML mapping; `shell:`/`erb:` is not a boolean (or true/false/yes/no/on/off string); `parameters:` is not a mapping |
| `ShellExpansionError` | shell expansion | An unmatched `$(` |
| `ShellCommandError` | shell expansion | A `$(command)` exited non-zero. `#command`, `#status` (Process::Status), `#stderr` are available; the message includes stderr when present |
| `CircularIncludeError` | `include` | The file to include is an ancestor in the current include chain |
| `IncludeDepthError` | `include` | Nesting would exceed `PM.config.max_include_depth` |
| `IncludeContextError` | `include` | Used from a string-parsed prompt (no directory) |
| `FileNotFoundError` | `insert` / `read` | The path is not an existing regular file |
| `DirectiveAlreadyRegisteredError` | `PM.register`, `PM::Directive.register_all` | A requested name is already taken (see [Custom Directives](../guides/custom-directives.md) for the exact policy) |
| `MissingParameterError` | `Parsed#to_s` | A parameter with a `null` default was not supplied. Message: `Missing required parameters: a, b` |
| `UnknownParameterError` | `Parsed#to_s` | Strict mode only: a template used a name that is neither a parameter nor a directive |

## Standard-library errors that pass through

| Error | When |
|---|---|
| `Errno::ENOENT` | `PM.parse` was given a file path that does not exist |
| `Psych::SyntaxError` | Front matter is not valid YAML |
| `Psych::DisallowedClass` | Front matter uses a Symbol or other non-permitted type (`Date` and `Time` are allowed) |
| `Psych::AliasesNotEnabled` | Front matter uses YAML anchors/aliases |
| `SyntaxError` | The ERB in the content does not compile |
| `NoMethodError` | A template called an unknown name **with arguments** (an unknown bare name renders as `""`, or raises `UnknownParameterError` in strict mode) |

## Rescuing

```ruby
begin
  PM.parse(path).to_s(values)
rescue PM::MissingParameterError => e
  # ask for the missing values
rescue PM::IncludeError => e
  # circular, too deep, or no file context
rescue PM::ShellCommandError => e
  warn e.stderr
rescue PM::Error => e
  # anything else PM raised
end
```
