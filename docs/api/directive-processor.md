# Directive Processor API Reference

The Directive Processor handles special instructions in prompts that begin with `//` and enable powerful prompt composition capabilities.

## Core Classes

### `PromptManager::DirectiveProcessor`

The main class responsible for processing directives within prompts.

#### Constructor

```ruby
processor = PromptManager::DirectiveProcessor.new(
  storage: storage_adapter,
  max_depth: 10,
  timeout: 30
)
```

**Parameters:**
- `storage` (Storage::Base): Storage adapter for resolving includes
- `max_depth` (Integer): Maximum include depth to prevent circular references (default: 10)
- `timeout` (Numeric): Processing timeout in seconds (default: 30)

#### Instance Methods

##### `process(content, context = {})`

Processes all directives in the given content.

**Parameters:**
- `content` (String): The prompt content containing directives
- `context` (Hash): Processing context and variables

**Returns:** String - Processed content with directives resolved

**Raises:**
- `PromptManager::DirectiveProcessingError` - If directive processing fails
- `PromptManager::CircularIncludeError` - If circular includes are detected

```ruby
processor = PromptManager::DirectiveProcessor.new(storage: adapter)
result = processor.process("//include header.txt\nHello World!")
```

##### `register_directive(name, handler)`

Registers a custom directive handler.

**Parameters:**
- `name` (String): Directive name (without //)
- `handler` (Proc): Handler that processes the directive

```ruby
processor.register_directive('timestamp') do |args, context|
  Time.current.strftime('%Y-%m-%d %H:%M:%S')
end
```

## Built-in Directives

### `//include` (alias: `//import`)

Includes content from another prompt file.

**Syntax:**
```text
//include path/to/file.txt
//include [VARIABLE_PATH].txt
//import common/header.txt
```

**Features:**
- Parameter substitution in paths: `//include templates/[TEMPLATE_TYPE].txt`
- Relative and absolute path resolution
- Circular include detection
- Nested include support

**Examples:**

```text
# Basic include
//include common/header.txt

# With parameter substitution
//include templates/[EMAIL_TYPE].txt

# Nested directory structure
//include emails/marketing/[CAMPAIGN_TYPE]/template.txt
```

### `//set`

Sets variables for use within the current prompt.

**Syntax:**
```text
//set VARIABLE_NAME value
//set CURRENT_DATE <%= Date.today %>
```

**Examples:**

```text
//set COMPANY_NAME Acme Corporation
//set SUPPORT_EMAIL support@[COMPANY_DOMAIN]
//set GREETING Hello [CUSTOMER_NAME]

Your message: [GREETING]
Contact us: [SUPPORT_EMAIL]
```

### `//if` / `//endif`

Conditional content inclusion.

**Syntax:**
```text
//if CONDITION
content to include if condition is true
//endif
```

**Examples:**

```text
//if [USER_TYPE] == 'premium'
🌟 Premium features are available!
//endif

//if [ORDER_TOTAL] > 100
🚚 Free shipping applied!
//endif
```

## Custom Directive Development

### Simple Directive Handler

```ruby
# Register a simple directive
processor.register_directive('upper') do |args, context|
  args.upcase
end

# Usage in prompt:
# //upper hello world
# Result: HELLO WORLD
```

### Complex Directive Handler

```ruby
# Register directive with parameter processing
processor.register_directive('format_currency') do |args, context|
  amount, currency = args.split(',').map(&:strip)
  formatted_amount = sprintf('%.2f', amount.to_f)
  
  case currency.downcase
  when 'usd', '$'
    "$#{formatted_amount}"
  when 'eur', '€'
    "€#{formatted_amount}"
  else
    "#{formatted_amount} #{currency}"
  end
end

# Usage in prompt:
# //format_currency [ORDER_TOTAL], USD
# Result: $123.45
```

### Directive with Context Access

```ruby
processor.register_directive('user_greeting') do |args, context|
  user_name = context.dig(:parameters, :user_name) || 'Guest'
  time_of_day = Time.current.hour < 12 ? 'morning' : 'afternoon'
  
  "Good #{time_of_day}, #{user_name}!"
end

# Usage in prompt:
# //user_greeting
# Result: Good morning, Alice!
```

## Error Handling

### Directive Processing Errors

```ruby
begin
  result = processor.process(content)
rescue PromptManager::DirectiveProcessingError => e
  puts "Directive error at line #{e.line_number}: #{e.message}"
  puts "Directive: #{e.directive}"
rescue PromptManager::CircularIncludeError => e
  puts "Circular include detected: #{e.include_chain.join(' -> ')}"
end
```

### Custom Error Handling

```ruby
processor.register_directive('safe_include') do |args, context|
  begin
    storage.read(args)
  rescue PromptManager::PromptNotFoundError
    "<!-- Template #{args} not found -->"
  end
end
```

## Advanced Features

### Conditional Directives

```ruby
processor.register_directive('feature_flag') do |args, context|
  feature_name, content = args.split(':', 2)
  
  if FeatureFlag.enabled?(feature_name)
    processor.process(content.strip, context)
  else
    ''
  end
end

# Usage:
# //feature_flag new_ui: Welcome to our new interface!
```

### Loop Directives

```ruby
processor.register_directive('foreach') do |args, context|
  array_name, template = args.split(':', 2)
  array_data = context.dig(:parameters, array_name.to_sym) || []
  
  array_data.map.with_index do |item, index|
    item_context = context.merge(
      parameters: context[:parameters].merge(
        item: item,
        index: index,
        first: index == 0,
        last: index == array_data.length - 1
      )
    )
    processor.process(template.strip, item_context)
  end.join("\n")
end

# Usage:
# //foreach items: - [ITEM.NAME]: $[ITEM.PRICE]
```

### Template Inheritance

```ruby
class TemplateInheritanceProcessor < PromptManager::DirectiveProcessor
  def initialize(**options)
    super(**options)
    register_built_in_directives
  end
  
  private
  
  def register_built_in_directives
    register_directive('extends') do |args, context|
      parent_content = storage.read(args)
      context[:parent_content] = parent_content
      ''  # Don't include anything at this point
    end
    
    register_directive('block') do |args, context|
      block_name, content = args.split(':', 2)
      context[:blocks] ||= {}
      context[:blocks][block_name] = content.strip
      ''  # Blocks are processed later
    end
    
    register_directive('yield') do |args, context|
      block_name = args.strip
      context.dig(:blocks, block_name) || ''
    end
  end
  
  def process(content, context = {})
    # First pass: extract blocks and parent template
    super(content, context)
    
    # Second pass: process parent template with blocks
    if context[:parent_content]
      super(context[:parent_content], context)
    else
      super(content, context)
    end
  end
end

# Usage:
# child.txt:
# //extends parent.txt
# //block content: This is child content
# //block title: Child Page

# parent.txt:
# <h1>//yield title</h1>
# <div>//yield content</div>
```

## Configuration

### Global Configuration

```ruby
PromptManager.configure do |config|
  config.directive_processor_class = CustomDirectiveProcessor
  config.max_include_depth = 5
  config.directive_timeout = 60
end
```

### Custom Processor

```ruby
class CustomDirectiveProcessor < PromptManager::DirectiveProcessor
  def initialize(**options)
    super(**options)
    register_custom_directives
  end
  
  private
  
  def register_custom_directives
    register_directive('env') { |args, context| ENV[args] }
    register_directive('random') { |args, context| rand(args.to_i) }
    register_directive('uuid') { |args, context| SecureRandom.uuid }
  end
end
```

## Performance Optimization

### Caching Directive Results

```ruby
class CachedDirectiveProcessor < PromptManager::DirectiveProcessor
  def initialize(**options)
    super(**options)
    @directive_cache = {}
  end
  
  def register_directive(name, &handler)
    cached_handler = lambda do |args, context|
      cache_key = "#{name}:#{args}:#{context.hash}"
      
      @directive_cache[cache_key] ||= handler.call(args, context)
    end
    
    super(name, &cached_handler)
  end
  
  def clear_cache
    @directive_cache.clear
  end
end
```

### Parallel Processing

```ruby
class ParallelDirectiveProcessor < PromptManager::DirectiveProcessor
  def process_includes(content, context)
    includes = extract_includes(content)
    
    # Process includes in parallel
    results = Parallel.map(includes) do |include_directive|
      process_single_include(include_directive, context)
    end
    
    # Replace includes with results
    replace_includes(content, includes, results)
  end
end
```

## Testing Directives

### RSpec Examples

```ruby
describe 'Custom Directive' do
  let(:processor) { PromptManager::DirectiveProcessor.new(storage: storage) }
  let(:storage) { instance_double(PromptManager::Storage::Base) }
  
  before do
    processor.register_directive('test') do |args, context|
      "processed: #{args}"
    end
  end
  
  it 'processes custom directive' do
    content = "//test hello world"
    result = processor.process(content)
    
    expect(result).to eq "processed: hello world"
  end
  
  it 'handles directive errors gracefully' do
    processor.register_directive('error') { |args, context| raise 'test error' }
    
    expect {
      processor.process("//error test")
    }.to raise_error(PromptManager::DirectiveProcessingError)
  end
end
```

## Best Practices

1. **Error Handling**: Always handle errors gracefully in directive handlers
2. **Performance**: Cache expensive operations in directive handlers
3. **Security**: Validate and sanitize directive arguments
4. **Documentation**: Document custom directive syntax and behavior
5. **Testing**: Write comprehensive tests for custom directives
6. **Naming**: Use descriptive names for custom directives
7. **Context**: Use context parameter to access prompt rendering state