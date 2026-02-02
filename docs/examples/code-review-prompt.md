# Code Review Prompt

A complete example of a parameterized code review prompt.

## The Prompt File

`prompts/code_review.md`:

```markdown
---
title: Code Review
provider: openai
model: gpt-4
temperature: 0.3
parameters:
  language: ruby
  code: null
  style_guide: ~/guides/default.md
---
Review the following <%= language %> code for:
- Correctness
- Performance
- Readability
- Security vulnerabilities

Apply the coding standards from this style guide:
<%= style_guide %>

Code to review:

<%= code %>
```

## Parsing

```ruby
require 'pm'

PM.configure { |c| c.prompts_dir = './prompts' }

parsed = PM.parse('code_review.md')
```

## Accessing Metadata

```ruby
parsed.metadata.title        #=> "Code Review"
parsed.metadata.provider     #=> "openai"
parsed.metadata.model        #=> "gpt-4"
parsed.metadata.temperature  #=> 0.3

parsed.metadata.parameters
#=> {"language" => "ruby", "code" => nil, "style_guide" => "~/guides/default.md"}
```

Use metadata to configure your LLM client:

```ruby
client = OpenAI::Client.new
response = client.chat(
  parameters: {
    model:       parsed.metadata.model,
    temperature: parsed.metadata.temperature,
    messages:    [{ role: 'user', content: prompt }]
  }
)
```

## Rendering

```ruby
# Minimal -- supply only the required parameter
prompt = parsed.to_s('code' => File.read('app.rb'))

# Override defaults
prompt = parsed.to_s(
  'code'        => File.read('main.py'),
  'language'    => 'python',
  'style_guide' => File.read('python_style.md')
)
```

## Shell Expansion in Action

The `style_guide` parameter defaults to `~/guides/default.md`. If shell expansion is enabled, the `~` is not expanded (it's not a shell variable). But you could use shell references elsewhere in the prompt:

```markdown
---
title: Code Review with Context
parameters:
  code: null
---
Repository: $(basename $(git rev-parse --toplevel))
Branch: $(git rev-parse --abbrev-ref HEAD)
Reviewer: $USER

Review this code:
<%= code %>
```

After parsing, the shell references are already resolved:

```ruby
parsed = PM.parse('code_review_context.md')
parsed.content
#=> "Repository: my-project\nBranch: main\nReviewer: dewayne\n\nReview this code:\n<%= code %>\n"
```
