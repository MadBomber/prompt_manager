# AI Agent Prompts

Patterns for building and managing prompt libraries for AI agents.

## Prompt Library Structure

Organize prompts by agent role and task:

```
~/.prompts/
  agents/
    code_assistant/
      system.md
      review.md
      refactor.md
      explain.md
    writer/
      system.md
      draft.md
      edit.md
    analyst/
      system.md
      summarize.md
      compare.md
  common/
    output_json.md
    output_markdown.md
    safety.md
```

## Configuration

```ruby
PM.configure { |c| c.prompts_dir = '~/.prompts' }
```

## System Prompt Pattern

`agents/code_assistant/system.md`:

```markdown
---
title: Code Assistant System Prompt
provider: anthropic
model: claude-sonnet-4-20250514
role: system
---
You are an expert software engineer. You help with code review,
refactoring, and explanation.

Current environment:
- OS: $(uname -s)
- User: $USER
- Working directory: $(pwd)

<%= include '../common/safety.md' %>
```

## Task Prompts with Parameters

`agents/code_assistant/review.md`:

```markdown
---
title: Code Review Task
role: user
parameters:
  code: null
  language: null
  focus: general
---
<%= include '../common/output_markdown.md' %>

Review the following <%= language %> code with a focus on <%= focus %>:

```<%= language %>
<%= code %>
```
```

## Custom Directives for Agent Integration

Register directives that fetch context dynamically:

```ruby
PM.register(:git_diff) do |_ctx|
  `git diff --cached`.chomp
end

PM.register(:recent_commits) do |_ctx, count|
  `git log --oneline -#{count}`.chomp
end

PM.register(:file_tree) do |ctx, path|
  dir = path || ctx.directory
  `find #{dir} -type f -name '*.rb' | head -20`.chomp
end
```

Use them in prompts:

```markdown
---
title: PR Review
parameters:
  focus: correctness
---
Review this PR with a focus on <%= focus %>.

Changes:
<%= git_diff %>

Recent commit context:
<%= recent_commits 5 %>

Project structure:
<%= file_tree nil %>
```

## Building a Prompt Runner

```ruby
require 'pm'

PM.configure { |c| c.prompts_dir = '~/.prompts' }

# Register project-specific directives
PM.register(:git_diff) { |_ctx| `git diff --cached`.chomp }

# Load and render
system_prompt = PM.parse('agents/code_assistant/system.md')
task_prompt   = PM.parse('agents/code_assistant/review.md')

messages = [
  { role: 'system', content: system_prompt.to_s },
  { role: 'user',   content: task_prompt.to_s(
    'code'     => File.read(ARGV[0]),
    'language' => 'ruby',
    'focus'    => 'security'
  )}
]

# Use metadata for model configuration
model = task_prompt.metadata.model || system_prompt.metadata.model
```

## Prompt Versioning

Keep prompts in version control alongside your code. The metadata tracks useful context:

```ruby
parsed = PM.parse('agents/code_assistant/review.md')

puts parsed.metadata.title        #=> "Code Review Task"
puts parsed.metadata.modified_at  #=> 2025-01-15 10:30:00 -0500
```

Use `modified_at` for cache invalidation or audit logging.

## Parameter Validation Pattern

Check required parameters before rendering:

```ruby
parsed = PM.parse('agents/code_assistant/review.md')

required = parsed.metadata.parameters
  .select { |_k, v| v.nil? }
  .keys

puts "Required parameters: #{required.join(', ')}"
#=> "Required parameters: code, language"
```
