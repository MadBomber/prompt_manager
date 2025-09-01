# Prompt Class API Reference

The `PromptManager::Prompt` class is the core interface for working with prompts in PromptManager.

## Class Methods

### `new(id:, **options)`

Creates a new Prompt instance.

**Parameters:**
- `id` (String): Unique identifier for the prompt
- `options` (Hash): Optional configuration parameters

**Options:**
- `erb_flag` (Boolean): Enable ERB template processing (default: false)
- `envar_flag` (Boolean): Enable environment variable substitution (default: false)  
- `storage` (Storage::Base): Custom storage adapter (default: configured adapter)

**Returns:** `PromptManager::Prompt` instance

**Examples:**

```ruby
# Basic prompt
prompt = PromptManager::Prompt.new(id: 'welcome_message')

# With ERB processing
prompt = PromptManager::Prompt.new(
  id: 'dynamic_prompt', 
  erb_flag: true
)

# With environment variables
prompt = PromptManager::Prompt.new(
  id: 'system_prompt',
  envar_flag: true
)

# All options
prompt = PromptManager::Prompt.new(
  id: 'advanced_prompt',
  erb_flag: true,
  envar_flag: true
)
```

## Instance Methods

### `render(parameters = {})`

Renders the prompt with the provided parameters.

**Parameters:**
- `parameters` (Hash): Key-value pairs for parameter substitution

**Returns:** String - The rendered prompt content

**Raises:**
- `PromptNotFoundError` - If the prompt file cannot be found
- `MissingParametersError` - If required parameters are not provided
- `DirectiveProcessingError` - If directive processing fails

**Examples:**

```ruby
# Basic rendering
result = prompt.render

# With parameters
result = prompt.render(
  customer_name: 'John Doe',
  order_id: 'ORD-123'
)

# With complex parameters
result = prompt.render(
  user: {
    name: 'Alice',
    email: 'alice@example.com'
  },
  items: ['Item 1', 'Item 2'],
  total: 99.99
)
```

### `save(content, **metadata)`

Saves prompt content to storage.

**Parameters:**
- `content` (String): The prompt content to save
- `metadata` (Hash): Optional metadata to store with the prompt

**Returns:** Boolean - Success status

**Examples:**

```ruby
# Save content
prompt.save("Hello [NAME], welcome to our service!")

# Save with metadata
prompt.save(
  "Your order [ORDER_ID] is ready!",
  category: 'notifications',
  author: 'system',
  version: '1.0'
)
```

### `content`

Retrieves the raw prompt content from storage.

**Returns:** String - The raw prompt content

**Example:**

```ruby
raw_content = prompt.content
puts raw_content  # "Hello [NAME]!"
```

### `parameters`

Extracts parameter names from the prompt content.

**Returns:** Array<String> - List of parameter names found in the prompt

**Example:**

```ruby
# Prompt content: "Hello [NAME], your order [ORDER_ID] is ready!"
params = prompt.parameters
puts params  # ['NAME', 'ORDER_ID']
```

### `delete`

Removes the prompt from storage.

**Returns:** Boolean - Success status

**Example:**

```ruby
prompt.delete
```

### `exists?`

Checks if the prompt exists in storage.

**Returns:** Boolean - True if prompt exists

**Example:**

```ruby
if prompt.exists?
  puts "Prompt found"
else
  puts "Prompt not found"
end
```

## Properties

### `id`

**Type:** String (read-only)

The unique identifier for the prompt.

```ruby
prompt = PromptManager::Prompt.new(id: 'welcome')
puts prompt.id  # "welcome"
```

### `erb_flag`

**Type:** Boolean

Whether ERB processing is enabled.

```ruby
prompt.erb_flag = true
```

### `envar_flag`

**Type:** Boolean

Whether environment variable substitution is enabled.

```ruby
prompt.envar_flag = true
```

### `storage`

**Type:** Storage::Base

The storage adapter used by this prompt.

```ruby
prompt.storage = PromptManager::Storage::FileSystemAdapter.new
```

## Parameter Processing

### Parameter Syntax

Parameters use square bracket syntax: `[PARAMETER_NAME]`

```ruby
# In prompt file:
# "Hello [NAME], your balance is $[BALANCE]"

prompt.render(
  name: 'Alice',
  balance: 1500.00
)
# Result: "Hello Alice, your balance is $1500.0"
```

### Nested Parameters

Parameters can reference nested hash values:

```ruby
# In prompt file:
# "User: [USER.NAME] ([USER.EMAIL])"

prompt.render(
  user: {
    name: 'Bob',
    email: 'bob@example.com'
  }
)
# Result: "User: Bob (bob@example.com)"
```

### Array Parameters

Arrays are joined with commas by default:

```ruby
# In prompt file:
# "Items: [ITEMS]"

prompt.render(items: ['Apple', 'Banana', 'Orange'])
# Result: "Items: Apple, Banana, Orange"
```

## Error Handling

### Exception Hierarchy

```ruby
PromptManager::Error
├── PromptNotFoundError
├── MissingParametersError  
├── DirectiveProcessingError
└── StorageError
```

### Error Details

```ruby
begin
  prompt.render
rescue PromptManager::MissingParametersError => e
  puts e.message              # Human readable message
  puts e.missing_parameters   # Array of missing parameter names
  puts e.prompt_id           # ID of the prompt that failed
rescue PromptManager::DirectiveProcessingError => e
  puts e.message             # Error details
  puts e.line_number        # Line where error occurred (if available)
  puts e.directive          # The directive that failed
end
```

## Threading and Concurrency

### Thread Safety

Prompt instances are **not** thread-safe. Create separate instances for each thread:

```ruby
# Thread-safe usage
threads = []
(1..10).each do |i|
  threads << Thread.new do
    # Each thread gets its own instance
    prompt = PromptManager::Prompt.new(id: 'worker_prompt')
    result = prompt.render(worker_id: i)
    puts result
  end
end

threads.each(&:join)
```

### Shared Storage

Storage adapters handle their own thread safety. Multiple Prompt instances can safely share the same storage adapter.

## Best Practices

### Instance Reuse

```ruby
# Good: Reuse instances when possible
prompt = PromptManager::Prompt.new(id: 'email_template')

customers.each do |customer|
  email_content = prompt.render(
    name: customer.name,
    email: customer.email
  )
  send_email(customer, email_content)
end
```

### Parameter Validation

```ruby
# Validate parameters before rendering
required_params = prompt.parameters
missing_params = required_params - params.keys

unless missing_params.empty?
  raise "Missing parameters: #{missing_params.join(', ')}"
end

result = prompt.render(params)
```

### Error Recovery

```ruby
def safe_render(prompt_id, params = {})
  prompt = PromptManager::Prompt.new(id: prompt_id)
  prompt.render(params)
rescue PromptManager::PromptNotFoundError
  "Default message when prompt unavailable"
rescue PromptManager::MissingParametersError => e
  "Missing: #{e.missing_parameters.join(', ')}"
rescue => e
  Rails.logger.error "Prompt render error: #{e.message}"
  "An error occurred"
end
```