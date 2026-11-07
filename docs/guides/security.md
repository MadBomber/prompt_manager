# Security

PM is a developer tool for prompts you wrote or reviewed. A prompt file is **code**,
and PM runs it with the full privileges of the Ruby process. This page spells out
what that means and which controls exist.

## What a prompt can do

| Feature | Capability |
|---|---|
| ERB (`<%= ... %>`) | Any Ruby expression, including `system`, `File`, `require` |
| Shell expansion (`$(command)`) | Any shell command, at parse time |
| `include 'path'` | Read, shell-expand, and ERB-render any readable file |
| `insert 'path'` / `read 'path'` | Read any readable file verbatim |
| Front matter `shell:` / `erb:` | Turn those stages on even if the global default is off (unless locked) |

Paths given to `include` and `insert` are resolved with `File.expand_path` and are
not confined to `prompts_dir`. `../../etc/passwd` works.

## The trust boundary

Only parse content you trust as much as you trust your own Ruby code. In particular:

- Do not run `PM.parse` on text that arrived over the network or from another user.
- Do not feed the output of a directive back through `PM.parse_string`; that
  re-applies shell and ERB expansion to data (the aia project hit exactly this with
  its `/webpage` directive).

## What PM does to limit blast radius

### Command output is inert

Shell expansion is a single left-to-right pass. The stdout of a `$(command)` is
spliced into the content and **never re-scanned**: a `$HOME` or `$(rm -rf /)` that a
command prints stays literal text. When ERB is enabled for the prompt, any `<%` in
command output, in the value of a `$VAR` or `${VAR}`, or formed where a non-empty
expansion meets the text beside it (`<$VAR` with a value starting `%`), is written as `<%%`,
which ERB renders as a literal `<%`, so neither can open an ERB tag.

This covers expansions in ordinary text. An expansion you write *inside* your own ERB
tag, such as `<%= "$VAR" %>`, is substituted before ERB runs and becomes part of that
Ruby code; escaping still changes its `<%` to `<%%`, but cannot make it safe. Do not put a variable or command you do not control inside an ERB tag;
pass the value as a parameter instead.

```ruby
PM.expand_shell(%q{$(printf '$HOME')})               #=> "$HOME"
PM.parse_string(%q{$(printf '<%%= 6*7 %%>')}).to_s   #=> "<%= 6*7 %>"
```

Inserted file contents are inert for the same reason: `insert` returns the file
verbatim and the result of a directive call is not re-parsed.

### Fenced code blocks are not expanded

Lines inside a ``` or ~~~ fence are copied through untouched, so a prompt that
*shows* shell syntax to the model does not *run* it.

### Locked configuration

```ruby
PM.configure do |c|
  c.shell = false
  c.erb   = false
end
PM.config.lock!
```

With the config locked, a file's `shell: true` or `erb: true` is ignored and the
global values win. Use this when the files come from a directory other people can
write to.

### Include depth limit

`PM.config.max_include_depth` (default 10) stops runaway include chains with
`PM::IncludeDepthError`. A true cycle raises `PM::CircularIncludeError` immediately.

### Front matter is loaded safely

Front matter goes through `YAML.safe_load` with only `Date` and `Time` permitted.
Symbols, aliases, and arbitrary objects raise `Psych` errors.

## What PM does not do

- It does not sandbox ERB or the shell. Ruby has no safe ERB mode; if you need one,
  disable ERB and shell for untrusted files and use parameters only.
- It does not confine `include` or `insert` to `prompts_dir`.
- It is not thread-safe for configuration or directive registration. Configure and
  register at boot; parsing and rendering from multiple threads afterwards is fine
  as long as nothing mutates `PM.config` or the registry concurrently.

## Checklist for serving prompts from a shared directory

1. `PM.config.shell = false` unless you need it, then `PM.config.lock!`.
2. Decide whether ERB is acceptable; if not, `PM.config.erb = false` before locking.
3. Keep `max_include_depth` at the default or lower.
4. Never pass directive output back into `PM.parse` or `PM.parse_string`.
