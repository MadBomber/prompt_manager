# Design Decisions

Key architectural choices and their rationale.

## OpenStruct for Metadata

`PM::Metadata` extends `OpenStruct`, providing dynamic dot-notation access to any YAML key without predeclaring attributes.

**Why:** Prompt metadata is inherently schemaless. Different prompts carry different keys (`provider`, `model`, `temperature`, `parameters`, custom keys). OpenStruct allows any key without configuration.

**Trade-off:** Slightly slower than a fixed Struct for attribute access, but metadata objects are small and accessed infrequently relative to the parsing work.

## ERB for Templates

ERB was chosen as the template engine rather than Mustache, Liquid, or a custom syntax.

**Why:**

- Ships with Ruby's standard library -- no additional dependencies
- Familiar to every Ruby developer
- Full Ruby expressions available (not just variable substitution)
- Custom directives integrate naturally as method calls

**Trade-off:** ERB can execute arbitrary Ruby, which is more powerful than needed for simple variable substitution. PM mitigates this by encouraging the use of parameters and directives rather than inline Ruby logic.

## Parse-Time vs Render-Time Split

Shell expansion runs at parse time. ERB rendering runs on demand at `to_s` time.

**Why:**

- Shell references (`$USER`, `$(date)`) represent the environment at the time the prompt is loaded. They should reflect current state when the file is read.
- ERB parameters represent per-invocation values that may change between calls. Deferring rendering allows the same parsed prompt to be rendered multiple times with different values.

## Separate Shell and ERB Flags

Both `shell` and `erb` can be independently enabled or disabled per file.

**Why:** Some prompts are documentation templates that should show `$VAR` syntax literally. Others need shell expansion but contain ERB syntax meant for a different renderer. Independent flags give full control.

## Include via ERB Directive

File inclusion uses `<%= include 'path.md' %>` rather than a preprocessor directive or custom syntax.

**Why:**

- Consistent with the ERB rendering model -- includes are just another method call
- Parameters flow naturally from parent to child
- Custom directives use the same mechanism, so the system is uniform
- No new syntax to learn

**Trade-off:** Includes only work when ERB is enabled. Setting `erb: false` disables includes.

## Circular Include Detection

PM tracks included file paths in a Set passed through the render chain.

**Why:** Circular includes would cause infinite recursion. The Set provides O(1) lookup and is threaded through the `RenderContext` without global state.

## Configuration as Singleton

`PM.config` returns a single `PM::Configuration` instance. Per-file metadata overrides it.

**Why:** A global default makes sense for project-wide settings like `prompts_dir`. The override mechanism means individual files always have the final say, avoiding surprises.

## UPPERCASE-Only Shell Variables

Only `$UPPER_CASE` variable names are expanded by shell expansion. `$lowercase` is left as-is.

**Why:** This avoids conflicts with ERB and other syntaxes that might use `$` followed by lowercase characters. Environment variables are conventionally uppercase, so this covers the practical use case without false matches.
