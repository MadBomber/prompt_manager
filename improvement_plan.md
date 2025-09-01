# PromptManager Gem Improvement Plan

## Overview
This document outlines potential improvements for the PromptManager gem based on a comprehensive code review conducted on 2025-09-01. The gem is currently at version 0.5.8 and is a key component of the AIA (AI Assistant) toolchain.

## Current State Assessment
- **Version**: 0.5.8
- **Overall Rating**: 8.5/10
- **Status**: Production-ready, actively maintained
- **Core Strengths**: Clean architecture, flexible storage adapters, thoughtful parameter management

## Improvement Categories

### 1. Parameter Format Flexibility
**Priority: HIGH**
**Effort: Low-Medium**

#### Support Multiple Parameter Formats
- Add support for `{{keyword}}` format (Liquid/Handlebars style)
- Maintain backward compatibility with `[KEYWORD]` format
- Allow users to configure their preferred format
- Auto-detect format from prompt content

#### Implementation Approach
```ruby
# Configuration options
PromptManager::Prompt.parameter_regex = :liquid  # Use {{param}} style
PromptManager::Prompt.parameter_regex = :square  # Use [PARAM] style (current)
PromptManager::Prompt.parameter_regex = :auto    # Auto-detect from content

# Or custom regex
PromptManager::Prompt.parameter_regex = /\{\{([^}]+)\}\}/

# Pre-defined format constants
PARAM_FORMATS = {
  square: /(\[[A-Z _|]+\])/,           # Current: [KEYWORD]
  liquid: /\{\{([^}]+)\}\}/,           # Liquid: {{keyword}}
  handlebars: /\{\{([^}]+)\}\}/,       # Same as liquid
  erb: /<%=\s*([^%>]+)\s*%>/,          # ERB style: <%= keyword %>
  dollar: /\$\{([^}]+)\}/              # Shell style: ${keyword}
}
```

#### Auto-detection Logic
- Scan prompt for different formats
- Use the most prevalent format found
- Warn if multiple formats detected

### 2. Markdown as First-Class Format
**Priority: HIGH**
**Effort: Medium**

#### Native Markdown Support
- Treat Markdown as the default prompt format
- Parse and preserve Markdown structure
- Special handling for:
  - Code blocks (preserve without parameter substitution)
  - Headers for prompt metadata
  - Lists for structured content
  - Front matter (YAML) for prompt configuration

#### Markdown-Aware Features with YAML Front Matter
```markdown
---
# Prompt Metadata (always preserved, never sent to LLM)
title: Customer Support Response
description: Template for responding to customer service inquiries with empathy and professionalism
version: 2.1
keywords: [customer-service, support, response-template]

# LLM Configuration (can be used by the calling application)
model: gpt-4
temperature: 0.7
max_tokens: 500
top_p: 0.9
frequency_penalty: 0.0
presence_penalty: 0.0

# Parameter Descriptions (for documentation and validation)
parameters:
  company_name:
    description: The name of the company providing support
    type: string
    required: true
  product:
    description: The product the customer is asking about
    type: string
    required: true
  customer_tier:
    description: Customer tier level (bronze, silver, gold, platinum)
    type: string
    default: silver
    enum: [bronze, silver, gold, platinum]
  customer_message:
    description: The customer's inquiry or complaint
    type: string
    required: true
    max_length: 1000
  max_words:
    description: Maximum words for the response
    type: integer
    default: 200
    min: 50
    max: 500
---

# System Prompt
You are a helpful customer support agent for {{company_name}}.

## Context
- Product: {{product}}
- Customer tier: {{customer_tier}}

## Task
Respond to the following customer inquiry:

```
{{customer_message}}
```

Keep your response under {{max_words}} words.
```

#### YAML Front Matter Standard Fields

##### Core Metadata
```yaml
---
# Required fields
title: Short descriptive title
description: One-line description of what this prompt does

# Optional but recommended
version: Semantic version (e.g., 1.2.3)
keywords: [tag1, tag2, tag3]  # For search and categorization
author: Developer name or team
created: 2024-01-15
updated: 2024-12-20
---
```

##### LLM Configuration
```yaml
---
# Common LLM parameters that apps can use
model: gpt-4  # or claude-3, llama-2, etc.
temperature: 0.7
max_tokens: 1000
top_p: 0.9
frequency_penalty: 0.0
presence_penalty: 0.0
stream: false
system_prompt: "You are a helpful assistant"  # If separate from main prompt
---
```

##### Parameter Documentation
```yaml
---
parameters:
  parameter_name:
    description: What this parameter is for
    type: string|integer|number|boolean|array
    required: true|false
    default: Default value if not provided
    enum: [option1, option2, option3]  # If limited choices
    min: 0  # For numbers
    max: 100  # For numbers
    max_length: 500  # For strings
    pattern: "^[A-Z]+$"  # Regex validation
    example: "Example value"
---
```

#### Benefits of YAML Front Matter
- **Self-documenting**: Parameters are documented where they're used
- **Validation-ready**: Type information enables runtime validation
- **Tool-friendly**: IDEs can provide better autocomplete with parameter descriptions
- **Searchable**: Keywords make prompts discoverable
- **Configuration**: LLM settings travel with the prompt

#### Implementation
```ruby
class PromptManager::Prompt
  attr_reader :metadata, :llm_config, :parameter_specs
  
  def initialize(id:, storage_adapter: nil)
    @storage_adapter = storage_adapter || self.class.storage_adapter
    load_prompt(id)
  end
  
  private
  
  def load_prompt(id)
    content = @storage_adapter.get(id: id)
    parse_markdown_prompt(content[:text])
  end
  
  def parse_markdown_prompt(text)
    # Extract front matter
    if text =~ /\A---\n(.*?)\n---\n(.*)/m
      front_matter = YAML.safe_load($1)
      prompt_body = $2
      
      # Separate metadata categories
      @metadata = extract_metadata(front_matter)
      @llm_config = extract_llm_config(front_matter)
      @parameter_specs = front_matter['parameters'] || {}
      
      # Process the prompt body
      @text = process_prompt_body(prompt_body)
    else
      @text = process_prompt_body(text)
    end
  end
  
  def extract_metadata(fm)
    {
      title: fm['title'],
      description: fm['description'],
      version: fm['version'],
      keywords: fm['keywords'] || [],
      author: fm['author'],
      created: fm['created'],
      updated: fm['updated']
    }.compact
  end
  
  def extract_llm_config(fm)
    {
      model: fm['model'],
      temperature: fm['temperature'],
      max_tokens: fm['max_tokens'],
      top_p: fm['top_p'],
      frequency_penalty: fm['frequency_penalty'],
      presence_penalty: fm['presence_penalty']
    }.compact
  end
  
  def validate_parameters(params)
    @parameter_specs.each do |name, spec|
      value = params[name] || params["{{#{name}}}"]
      
      # Check required
      if spec['required'] && value.nil?
        raise ParameterError, "Required parameter '#{name}' is missing"
      end
      
      # Apply default if needed
      if value.nil? && spec['default']
        params[name] = spec['default']
        next
      end
      
      # Type validation
      validate_type(name, value, spec['type']) if value && spec['type']
      
      # Enum validation
      if spec['enum'] && value && !spec['enum'].include?(value)
        raise ParameterError, "Parameter '#{name}' must be one of: #{spec['enum'].join(', ')}"
      end
      
      # Range validation for numbers
      if spec['type'] == 'integer' || spec['type'] == 'number'
        validate_range(name, value, spec['min'], spec['max'])
      end
      
      # Length validation for strings
      if spec['type'] == 'string' && spec['max_length'] && value.length > spec['max_length']
        raise ParameterError, "Parameter '#{name}' exceeds maximum length of #{spec['max_length']}"
      end
    end
  end
end
```

#### Usage Example
```ruby
prompt = PromptManager::Prompt.new(id: 'customer_support')

# Access metadata
puts prompt.metadata[:title]        # "Customer Support Response"
puts prompt.metadata[:description]  # "Template for responding to..."

# Access LLM configuration
puts prompt.llm_config[:temperature]  # 0.7
puts prompt.llm_config[:model]        # "gpt-4"

# Get parameter documentation
prompt.parameter_specs.each do |name, spec|
  puts "#{name}: #{spec['description']}"
  puts "  Type: #{spec['type']}, Required: #{spec['required']}"
end

# Parameters are validated before substitution
prompt.parameters = {
  'company_name' => 'Acme Corp',
  'product' => 'Widget Pro',
  'customer_tier' => 'gold',
  'customer_message' => 'My widget is broken!'
}  # Validates against parameter_specs
```

#### Benefits
- Prompts are more readable and maintainable
- Can leverage Markdown editors and preview tools
- Better documentation within prompts
- Supports rich formatting for complex prompts
- Self-contained prompt packages with all configuration

### 2a. Comment Handling in Markdown Prompts
**Priority: HIGH**
**Effort: Low-Medium**

#### The Challenge
Markdown files (`.md`) don't have a standard inline comment syntax that's hidden from rendering. We need a way to include developer notes that won't be sent to the LLM.

#### Proposed Solutions

##### Option 1: HTML Comments (Recommended)
```markdown
<!-- DEVELOPER NOTE: This prompt requires customer_name to be validated -->
# Customer Service Response

<!-- TODO: Add tone parameter to control formality -->
Hello {{customer_name}},

<!-- The following section is critical for compliance -->
We understand your concern about {{issue}}.
```
**Pros:**
- Standard HTML/Markdown convention
- Invisible in rendered Markdown
- Supported by all Markdown editors
- GitHub/GitLab render them as hidden

**Cons:**
- More verbose than `#` comments
- Can be accidentally included if not stripped properly

##### Option 2: Custom Markers
```markdown
%% DEVELOPER: This is a comment that won't be sent to LLM %%
# System Prompt

%% TODO: Add parameter validation %%
You are {{role}}.

### OR using different markers ###

[//]: # (This is a comment using Markdown's link reference syntax)
[//]: # (It's completely hidden in rendered output)
```
**Pros:**
- `%%` is used by Obsidian for comments
- `[//]: #` is valid Markdown that renders as nothing
- Can choose syntax that suits the team

**Cons:**
- Not universally recognized
- May confuse developers unfamiliar with the convention

##### Option 3: Front Matter Comments
```yaml
---
title: Customer Support
# Comments in YAML front matter
# These are for developers only
_dev_notes: |
  This prompt requires the following parameters:
  - customer_name: validated email
  - issue: max 500 chars
_todo:
  - Add sentiment analysis
  - Test with GPT-4
---
```
**Pros:**
- Keeps all metadata in one place
- YAML supports comments natively
- Can have structured developer notes

**Cons:**
- Only works for header comments, not inline
- Might clutter front matter

##### Option 4: Special Code Blocks
````markdown
```comment
This is a developer comment block.
It will be stripped before sending to LLM.
Can contain multiple lines and formatting.
```

# Actual Prompt
Hello {{name}}

```dev-note
Remember to validate the name parameter
```
````
**Pros:**
- Clear visual distinction
- Can contain formatted content
- Easy to parse and remove

**Cons:**
- Takes more vertical space
- Not standard Markdown

#### Implementation Strategy
```ruby
class MarkdownPromptProcessor
  COMMENT_PATTERNS = {
    html: /<!--.*?-->/m,
    obsidian: /%%.*?%%/m,
    link_ref: /\[\/\/\]: # \(.*?\)/,
    code_block: /```(?:comment|dev-note|note).*?```/m
  }
  
  def strip_comments(content, style: :html)
    content.gsub(COMMENT_PATTERNS[style], '')
  end
  
  # Support multiple comment styles simultaneously
  def strip_all_comments(content)
    COMMENT_PATTERNS.values.reduce(content) do |text, pattern|
      text.gsub(pattern, '')
    end
  end
end
```

#### Configuration Options
```ruby
PromptManager.configure do |config|
  config.prompt_extension = '.md'
  config.comment_style = :html  # or :obsidian, :all
  config.preserve_comments_in_storage = true  # Keep comments in .md file
  config.strip_comments_for_llm = true       # Remove before sending to LLM
end
```

### 2b. The __END__ Marker in Markdown
**Priority: HIGH**
**Effort: Low**

#### Preserving the __END__ Convention
The `__END__` marker is a valuable convention from Ruby (and Perl) that provides a clear demarcation for "everything after this is not part of the main content." This is especially useful for:
- Extensive developer notes
- Test data and examples
- Changelog for the prompt
- Scratchpad for prompt iterations
- Reference materials

#### Implementation in Markdown Context
```markdown
---
title: Customer Support Agent
version: 3.2
---

# System Prompt
You are a helpful customer support agent for {{company_name}}.

<!-- inline comment about the tone parameter -->
Maintain a {{tone}} tone throughout your response.

## Your Task
Respond to: {{customer_message}}

__END__

# Developer Notes
This prompt has gone through several iterations:
- v3.2: Added tone parameter
- v3.1: Simplified the system prompt  
- v3.0: Complete rewrite for GPT-4

# Test Cases
- customer_message: "I'm angry about my broken product!"
  tone: "empathetic"
  expected: Should acknowledge frustration

# Random thoughts
Maybe we should add a parameter for response length?
The client mentioned they want more formal responses for enterprise customers.

# Old version we might want to reference
You are a customer support representative who always...
(this was too verbose)
```

#### Benefits of Keeping __END__
1. **Unstructured Space**: Everything after `__END__` can be free-form without worrying about syntax
2. **Backward Compatible**: Existing prompts using this convention still work
3. **Clear Separation**: Visually obvious where the prompt ends
4. **No Escaping Needed**: After `__END__`, no need to worry about HTML comment syntax
5. **Markdown Friendly**: Can still use Markdown formatting in the notes section for readability

#### Processing Logic
```ruby
class MarkdownPromptProcessor
  def process(content)
    # Split at __END__ marker
    parts = content.split(/^__END__$/m, 2)
    
    prompt_content = parts[0]
    developer_notes = parts[1] # Everything after __END__ (if present)
    
    # Process only the prompt content
    prompt_content = strip_html_comments(prompt_content)
    prompt_content = substitute_parameters(prompt_content)
    
    # Return processed prompt (developer_notes are never sent to LLM)
    prompt_content
  end
  
  def save_to_storage(content)
    # When saving, preserve everything including __END__ section
    content
  end
end
```

#### Combined Comment Strategy
```markdown
<!-- Quick inline comment -->
# Main Prompt

Here's the prompt with {{parameters}}.

<!-- Another inline note about the section below -->
## Special Instructions

Follow these guidelines:
<!-- TODO: Add more guidelines -->
- Be concise
- Be helpful

__END__

Everything down here is free-form developer notes.
No need for <!-- --> syntax.
Can paste examples, old versions, test cases, etc.

This section is NEVER sent to the LLM but is preserved in the .md file.
```

#### Configuration
```ruby
PromptManager.configure do |config|
  config.prompt_extension = '.md'
  config.comment_style = :html           # For inline comments
  config.honor_end_marker = true         # Respect __END__ marker
  config.end_marker = '__END__'          # Customizable if needed
  config.strip_comments_for_llm = true   # Remove both HTML comments and __END__ section
end
```

### 3. Performance Optimizations
**Priority: Medium**
**Effort: Medium**

#### Optimize Parameter Parsing
- Current: Regex scanning on every parameter extraction
- Proposed: Cache parsed parameters with dirty tracking
- Implement lazy evaluation for large prompts

#### Benchmark-Driven Improvements
- Add performance benchmarks to test suite
- Profile regex operations for large prompts (>10KB)
- Consider using StringScanner for improved parsing performance

### 3. Storage Adapter Enhancements
**Priority: High**
**Effort: Low-Medium**

#### Formalize Storage Adapter Interface
```ruby
# lib/prompt_manager/storage/base_adapter.rb
module PromptManager
  module Storage
    class BaseAdapter
      def get(id:)
        raise NotImplementedError
      end
      
      def save(id:, text:, parameters:)
        raise NotImplementedError
      end
      
      def delete(id:)
        raise NotImplementedError
      end
      
      def list
        raise NotImplementedError
      end
      
      def search(term:)
        raise NotImplementedError
      end
    end
  end
end
```

#### Add New Storage Adapters
- **RedisAdapter**: For high-performance caching
- **S3Adapter**: For cloud storage
- **PostgreSQLAdapter**: With JSONB support for parameters
- **MemoryAdapter**: For testing and temporary storage

### 4. Serialization Flexibility
**Priority: Medium**
**Effort: Low**

#### Make Serialization Pluggable
- Extract serialization into strategy pattern
- Support multiple formats:
  - JSON (current)
  - YAML
  - MessagePack (for performance)
  - Custom serializers

```ruby
class FileSystemAdapter
  def initialize(serializer: JSONSerializer.new)
    @serializer = serializer
  end
end
```

### 5. Enhanced Directive System
**Priority: Medium-High**
**Effort: High**

#### Directive Registry
- Allow registration of custom directives
- Plugin architecture for directive processors
- Built-in directives:
  - `//include` (existing)
  - `//template` - ERB template processing
  - `//exec` - Execute shell commands
  - `//fetch` - Fetch content from URLs
  - `//cache` - Cache directive results

#### Directive Middleware Chain
```ruby
class DirectiveProcessor
  def register(name, handler)
    @handlers[name] = handler
  end
  
  def process(directive_line)
    middleware_chain.call(directive_line)
  end
end
```

### 6. Parameter Management Improvements
**Priority: High**
**Effort: Medium**

#### Parameter Validation
- Add parameter type hints: `[NAME:string]`, `[AGE:number]`, `[ACTIVE:boolean]`
- Validation rules: required, optional, default values
- Pattern matching: `[EMAIL:email]`, `[URL:url]`

#### Parameter Inheritance
- Support prompt templates with parameter inheritance
- Base prompts that other prompts can extend

### 7. Testing and Quality Improvements
**Priority: Medium**
**Effort: Low**

#### Enhanced Test Coverage
- Add integration tests for storage adapters
- Property-based testing for parameter substitution
- Mutation testing to ensure test quality

#### CI/CD Improvements
- Add GitHub Actions for automated testing
- Code coverage badges
- Automated gem releases

### 8. Documentation and Examples
**Priority: Low-Medium**
**Effort: Low**

#### Improve Documentation
- Add YARD documentation to all public methods
- Create a documentation site (GitHub Pages)
- Video tutorials for common use cases
- Migration guides for version upgrades

#### Extended Examples
- Real-world use cases
- Integration examples with popular AI libraries
- Best practices guide

### 9. Backwards Compatibility Strategy
**Priority: High**
**Effort: Ongoing**

#### Versioning Strategy
- Follow Semantic Versioning strictly
- Deprecation warnings for breaking changes
- Migration tools for major version upgrades

### 10. New Features
**Priority: Low-Medium**
**Effort: Variable**

#### Prompt Versioning
- Track prompt history
- Rollback capabilities
- Diff viewing between versions

#### Prompt Marketplace/Sharing
- Export/import prompt packages
- Prompt templates repository
- Community sharing features

## Breaking Changes for v0.9.0

Since we're making format changes, let's bundle all breaking changes into v0.9.0:

### 1. File Format Changes (BREAKING)
- **Default extension**: `.txt` → `.md`
- **Parameter format**: `[KEYWORD]` → `{{keyword}}` (auto-detect for migration)
- **Front matter**: Add YAML front matter support
- **Serialization**: Keep JSON as default, add pluggable support (YAML, MessagePack optional)

### 2. API Changes (BREAKING)
```ruby
# Current v0.5.x API
prompt = PromptManager::Prompt.new(id: 'test')
prompt.parameters['[NAME]'] = 'value'

# New v0.9.0 API
prompt = PromptManager::Prompt.new(id: 'test')
prompt.set_parameter('name', 'value')  # Cleaner API, but keeps '[NAME]' internally
prompt.metadata[:title]  # Access to front matter
prompt.llm_config[:temperature]  # LLM configuration
```

### 3. Storage Adapter Interface (BREAKING)
```ruby
# v0.5.x - informal interface
class MyAdapter
  def get(id:); end
  def save(id:, text:, parameters:); end
end

# v0.9.0 - formal interface with base class
class MyAdapter < PromptManager::Storage::BaseAdapter
  def get(id:); end
  def save(id:, text:, parameters:, metadata: {}, llm_config: {}); end
  def delete(id:); end
  def list(filter: {}); end
  def search(query:, filters: {}); end
end
```

### 4. Parameter Handling (BREAKING)
```ruby
# v0.5.x - manual parameter management
prompt.parameters['[NAME]'] = ['value1', 'value2']

# v0.9.0 - simplified with validation  
prompt.set_parameter('name', 'value2')  # Automatically manages history, stores as '[NAME]'
prompt.validate_parameters!  # Based on front matter specs
```

### 5. Configuration Changes (BREAKING)
```ruby
# v0.5.x
PromptManager::Storage::FileSystemAdapter.config do |config|
  config.prompts_dir = 'path'
  config.prompt_extension = '.txt'
  config.params_extension = '.json'
end

# v0.9.0
PromptManager.configure do |config|
  config.storage_adapter = :file_system
  config.prompts_dir = 'path'
  config.prompt_extension = '.md'
  config.parameter_format = :liquid  # {{}} style  
  config.serializer = :json  # Keep JSON as default
  config.validate_parameters = true
end
```

### 6. What We're NOT Changing (Staying Backward Compatible)

#### Keep JCL-Style Directives (NO CHANGE)
```ruby
# Keeping current JCL-style directives
//include path/to/file.txt
//import another/file.md

# These remain unchanged - familiar and working well
```

#### Keep Parameter Key Format (NO CHANGE) 
```ruby
# Internal storage keeps current format
{
  '[NAME]' => ['Alice', 'Bob'],
  '[AGE]' => ['25', '30']
}

# New API abstracts this away:
prompt.set_parameter('name', 'Bob')  # Becomes '[NAME]' internally
prompt.get_parameter('name')         # Returns value for '[NAME]'
```

#### Keep JSON as Default Serializer (NO CHANGE)
```ruby
# JSON remains the default for .json parameter files
# YAML support added as optional feature for those who want it
```

#### Option C: Error Handling Overhaul
```ruby
# v0.5.x - basic errors
begin
  prompt.to_s
rescue PromptManager::Error => e
  # Generic error
end

# v1.0 - specific error types
begin
  prompt.to_s
rescue PromptManager::ParameterValidationError => e
  puts "Invalid parameter: #{e.parameter_name}"
rescue PromptManager::TemplateParsingError => e  
  puts "Template error at line #{e.line_number}"
rescue PromptManager::DirectiveError => e
  puts "Directive '#{e.directive}' failed: #{e.message}"
end
```

#### Option D: Prompt Class Restructure
```ruby
# v0.5.x - monolithic Prompt class
class Prompt
  # Everything mixed together
end

# v1.0 - separation of concerns
class Prompt
  include Parameterizable
  include Validatable
  include Serializable
  
  attr_reader :metadata, :llm_config, :content
end
```

## Implementation Roadmap (Revised)

### v0.9.0 - Breaking Changes Release (The Big Jump)
- [ ] Default to new formats (.md, {{}} parameters) 
- [ ] YAML front matter support with metadata and LLM config
- [ ] New cleaner API (`set_parameter`, `get_parameter`)
- [ ] Formal storage adapter interface with base class
- [ ] Parameter validation system based on front matter
- [ ] Migration tools for automatic format conversion
- [ ] Backward compatibility for existing parameter access
- [ ] Keep JCL directives, bracket storage, JSON serialization

### v1.0.0 - Stability Release
- [ ] Performance optimizations and bug fixes
- [ ] Complete documentation with migration guide
- [ ] Production hardening based on v0.9 feedback

### v1.1.0 - Enhanced Features
- [ ] New storage adapters (Redis, S3)
- [ ] Performance optimizations
- [ ] Directive registry system
- [ ] Template inheritance

## Migration Strategy

### Automated Migration Tool
```bash
# Convert existing prompts to v0.9.0 format  
prompt_manager migrate --from=0.5.x --to=0.9 --path=~/.prompts

# Preview changes without applying
prompt_manager migrate --dry-run --path=~/.prompts

# Convert specific aspects
prompt_manager migrate --parameters-only --path=~/.prompts
prompt_manager migrate --add-frontmatter --path=~/.prompts
```

### Migration Process
1. **Backup**: Always backup existing prompt directory
2. **Convert files**: `.txt` → `.md` with front matter injection
3. **Update parameters**: `[KEYWORD]` → `{{keyword}}`
4. **Generate specs**: Create parameter documentation in front matter
5. **Update JSON**: Convert parameter files to YAML (optional)

### Migration Example
```ruby
# Before migration: joke.txt
Tell me a [KIND] joke about [SUBJECT]

# joke.json
{
  "[KIND]": ["pun", "family friendly"],
  "[SUBJECT]": ["parrot", "garbage man"]
}
```

```markdown
# After migration: joke.md
---
title: Joke Generator
description: Generates jokes of specified type about a subject  
version: 0.9.0
parameters:
  kind:
    description: Type of joke to generate
    type: string
    required: true
    example: "pun"
  subject:
    description: Subject of the joke
    type: string  
    required: true
    example: "parrot"
---

Tell me a {{kind}} joke about {{subject}}
```

### Backward Compatibility Layer (v0.9.x)
```ruby
# Support both old and new syntax during transition
class Prompt
  def parameters=(params)
    if params.keys.first&.include?('[')
      # Old format: convert automatically
      deprecation_warning "Bracket format deprecated. Use set_parameter() instead."
      params.each do |key, value|
        clean_key = key.gsub(/[\[\]]/, '').downcase
        set_parameter(clean_key, value)
      end
    else
      # New format
      params.each { |key, value| set_parameter(key, value) }
    end
  end
end
```

## Discussion Points

### Questions to Consider
1. Should {{keyword}} format become the default in v1.0?
2. How should we handle mixed parameter formats in a single prompt?
3. Should Markdown front matter replace the current comment-based metadata?
4. Is there value in supporting Liquid filters like {{name | upcase}}?
5. Should code blocks in Markdown always be parameter-substitution-free zones?
6. What other Markdown features need special handling (tables, links, images)?

### Trade-offs
- **Format Flexibility vs Complexity**: Supporting multiple formats adds parsing complexity
- **Markdown Features vs Performance**: Full Markdown parsing may impact performance
- **Backward Compatibility vs Modern Standards**: Moving to {{}} format may break existing prompts
- **Features vs Maintenance**: More formats mean more edge cases to handle

## Next Steps
1. Prioritize improvements based on user feedback
2. Create GitHub issues for each improvement
3. Set up a project board for tracking progress
4. Establish contribution guidelines for community involvement
5. Consider creating a beta release channel for testing new features

## Notes
- This plan is a living document and should be updated as development progresses
- Community feedback should be actively sought and incorporated
- Breaking changes should be minimized and well-documented when necessary

---

*Last Updated: 2025-09-01*
*Version: 1.0*