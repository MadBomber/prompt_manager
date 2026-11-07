# Design Decisions

Key architectural choices and their rationale.

## Hash-backed Metadata

`PM::Metadata` wraps a Hash and resolves unknown method names to keys, giving dynamic dot-notation access to any YAML key without predeclaring attributes.

**Why:** Prompt metadata is inherently schemaless. Different prompts carry different keys (`provider`, `model`, `temperature`, `parameters`, custom keys).

**Why not OpenStruct:** Earlier versions subclassed `OpenStruct`. It pulled in the `ostruct` gem (PM's only runtime dependency), silently ignored keys that collide with `Object` methods such as `hash` or `method`, and is discouraged by Ruby itself. The Hash-backed class keeps the same surface (dot access, predicates, `[]`, `to_h`) with zero dependencies and a defined rule for name collisions.

## Data for Parsed and RenderContext

`PM::Parsed` and `PM::RenderContext` are `Data.define` classes rather than `Struct`s.

**Why:** Both are value objects that nothing should mutate after creation. `Data` gives keyword construction, `with`, and immutability for free, and `RenderContext.new` with no arguments produces a sensible empty context, which makes directives easy to test in isolation.

## ERB for Templates

ERB was chosen as the template engine rather than Mustache, Liquid, or a custom syntax.

**Why:**

- Ships with Ruby's standard library, no additional dependencies
- Familiar to every Ruby developer
- Full Ruby expressions available (not just variable substitution)
- Custom directives integrate naturally as method calls

**Trade-off:** ERB can execute arbitrary Ruby. PM does not try to sandbox it; the
[Security guide](../guides/security.md) states the trust model instead. What PM does do
is keep data from becoming code: command output, environment variable values and
inserted files are inert in ordinary text (not inside the author's own ERB tag), and
`PM.config.lock!` stops a file from switching ERB on when the host turned it off.

## Parse-Time vs Render-Time Split

Shell expansion runs at parse time. ERB rendering runs on demand at `to_s` time.

**Why:**

- Shell references (`$USER`, `$(date)`) represent the environment at the time the prompt is loaded. They should reflect current state when the file is read.
- ERB parameters represent per-invocation values that may change between calls. Deferring rendering allows the same parsed prompt to be rendered multiple times with different values.

## Single-pass Shell Expansion

The expander scans the content once, left to right, and never re-scans text it has emitted.

**Why:** The 1.0 implementation ran command substitution and then variable expansion as two `gsub` passes over the whole string, so a command whose output contained `$HOME` or `<%= %>` had that output expanded or evaluated. One pass with an explicit cursor makes the rule simple: source text is expanded, output is data. It also makes `\$` escapes and fence skipping possible, since the scanner knows where it is.

## Separate Shell and ERB Flags, Lockable

Both `shell` and `erb` can be independently enabled or disabled per file, and the host can lock the global values.

**Why:** Some prompts are documentation templates that should show `$VAR` syntax literally. Others need shell expansion but contain ERB syntax meant for a different renderer. Independent flags give full control. Locking exists because "the file always wins" is the wrong default when the files come from somewhere the host does not control.

## Include via ERB Directive

File inclusion uses `<%= include 'path.md' %>` rather than a preprocessor directive or custom syntax.

**Why:**

- Consistent with the ERB rendering model: includes are just another method call
- Parameters flow naturally from parent to child
- Custom directives use the same mechanism, so the system is uniform
- No new syntax to learn

**Trade-off:** Includes only work when ERB is enabled. Setting `erb: false` disables includes.

## Ancestor-chain Circular Detection

PM tracks the files on the current include path in a Set passed through the `RenderContext`, plus a depth counter.

**Why:** Circular includes would cause infinite recursion. Tracking ancestors rather than every file rendered so far means a shared fragment can be included twice by siblings (1.0 wrongly reported that as a cycle). The depth limit (`max_include_depth`) is a second guard for chains that are long rather than circular.

## Name Resolution Order

Inside a template, a bare name resolves to a parameter when called with no arguments, then to a directive, then to `nil`.

**Why:** Parameters and directives share one namespace, and downstream libraries (aia, robot_lab) have templates whose parameter names coincide with directive names. "Parameter wins without arguments, directive wins with arguments" matches how both are actually written and never breaks a working template. Strict mode is opt-in because rendering `""` for a missing value is the behaviour 1.0 users rely on.

## Typed Errors, Backward-compatible Parameter Errors

Everything PM raises descends from `PM::Error`, except the parameter errors, which descend from `ArgumentError`.

**Why:** Callers need to tell "this prompt is broken" from "this parameter is missing" from "this shell command failed" without string matching. `MissingParameterError` stays an `ArgumentError` with the same message because existing code (robot_lab among it) rescues `ArgumentError` and reads the message.

## Configuration as Singleton

`PM.config` returns a single `PM::Configuration` instance.

**Why:** A global default makes sense for project-wide settings like `prompts_dir`. It is not synchronized; PM expects configuration and directive registration to happen at boot, and parsing to be the concurrent part.

## UPPERCASE-Only Shell Variables

Only `$UPPER_CASE` variable names are expanded by shell expansion. `$lowercase` is left as-is.

**Why:** This avoids conflicts with ERB and other syntaxes that might use `$` followed by lowercase characters. Environment variables are conventionally uppercase, so this covers the practical use case without false matches.

## Packaging

The gem ships only `lib/`, `README.md`, `CHANGELOG.md`, and `LICENSE`.

**Why:** 1.0.x shipped the whole repository, including a GIF and an MP4, for a 9.6 MB gem whose code is under 30 KB. Documentation lives on the site; the gem carries the code.
