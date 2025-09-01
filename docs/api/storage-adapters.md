# Storage Adapters API Reference

PromptManager uses a storage adapter pattern to provide flexible backends for prompt storage and retrieval.

## Base Storage Adapter

All storage adapters inherit from `PromptManager::Storage::Base` and must implement the core interface.

### `PromptManager::Storage::Base`

The abstract base class that defines the storage adapter interface.

#### Required Methods

##### `read(prompt_id)`

Reads prompt content from storage.

**Parameters:**
- `prompt_id` (String): Unique identifier for the prompt

**Returns:** String - The prompt content

**Raises:**
- `PromptManager::PromptNotFoundError` - If prompt doesn't exist
- `PromptManager::StorageError` - For storage-related errors

```ruby
def read(prompt_id)
  # Implementation must return prompt content as string
  # or raise PromptNotFoundError if not found
end
```

##### `write(prompt_id, content)`

Writes prompt content to storage.

**Parameters:**
- `prompt_id` (String): Unique identifier for the prompt
- `content` (String): The prompt content to store

**Returns:** Boolean - True on success

**Raises:**
- `PromptManager::StorageError` - For storage-related errors

```ruby
def write(prompt_id, content)
  # Implementation must store content and return true
  # or raise StorageError on failure
end
```

##### `exist?(prompt_id)`

Checks if a prompt exists in storage.

**Parameters:**
- `prompt_id` (String): Unique identifier for the prompt

**Returns:** Boolean - True if prompt exists

```ruby
def exist?(prompt_id)
  # Implementation must return boolean
end
```

##### `delete(prompt_id)`

Removes a prompt from storage.

**Parameters:**
- `prompt_id` (String): Unique identifier for the prompt

**Returns:** Boolean - True if successfully deleted

```ruby
def delete(prompt_id)
  # Implementation must remove prompt and return success status
end
```

##### `list`

Returns all available prompt identifiers.

**Returns:** Array<String> - Array of prompt IDs

```ruby
def list
  # Implementation must return array of all prompt IDs
end
```

#### Optional Methods

##### `initialize(**options)`

Constructor for storage adapter configuration.

```ruby
def initialize(**options)
  super
  # Custom initialization logic
end
```

##### `clear`

Removes all prompts from storage (optional).

**Returns:** Boolean - True on success

```ruby
def clear
  # Optional: implement to support clearing all prompts
end
```

## Built-in Storage Adapters

### FileSystemAdapter

Stores prompts as files in a directory structure.

```ruby
adapter = PromptManager::Storage::FileSystemAdapter.new(
  prompts_dir: '/path/to/prompts',
  file_extensions: ['.txt', '.md', '.prompt'],
  create_directories: true
)
```

**Configuration Options:**

- `prompts_dir` (String|Array): Directory path(s) to search
- `file_extensions` (Array): File extensions to recognize (default: `['.txt', '.md']`)
- `create_directories` (Boolean): Create directories if they don't exist (default: `true`)

**Features:**
- Hierarchical prompt organization with subdirectories
- Multiple search paths with fallback
- Automatic file extension detection
- Thread-safe file operations

### ActiveRecordAdapter

Stores prompts in a database using ActiveRecord.

```ruby
adapter = PromptManager::Storage::ActiveRecordAdapter.new(
  model_class: Prompt,
  id_column: :prompt_id,
  content_column: :content,
  scope: -> { where(active: true) }
)
```

**Configuration Options:**

- `model_class` (Class): ActiveRecord model class
- `id_column` (Symbol): Column containing prompt ID (default: `:prompt_id`)
- `content_column` (Symbol): Column containing prompt content (default: `:content`)
- `scope` (Proc): Additional query scope (optional)

**Features:**
- Full database integration with Rails
- Transaction support
- Query optimization
- Multi-tenancy support

## Custom Adapter Implementation

### Example: MemoryAdapter

```ruby
class MemoryAdapter < PromptManager::Storage::Base
  def initialize(**options)
    super
    @prompts = {}
    @mutex = Mutex.new
  end
  
  def read(prompt_id)
    @mutex.synchronize do
      content = @prompts[prompt_id]
      raise PromptManager::PromptNotFoundError.new("Prompt '#{prompt_id}' not found") unless content
      content
    end
  end
  
  def write(prompt_id, content)
    @mutex.synchronize do
      @prompts[prompt_id] = content
    end
    true
  end
  
  def exist?(prompt_id)
    @mutex.synchronize { @prompts.key?(prompt_id) }
  end
  
  def delete(prompt_id)
    @mutex.synchronize do
      @prompts.delete(prompt_id) ? true : false
    end
  end
  
  def list
    @mutex.synchronize { @prompts.keys }
  end
  
  def clear
    @mutex.synchronize { @prompts.clear }
    true
  end
end
```

### Example: HTTPAdapter

```ruby
require 'net/http'
require 'json'

class HTTPAdapter < PromptManager::Storage::Base
  def initialize(base_url:, api_token: nil, **options)
    super(**options)
    @base_url = base_url.chomp('/')
    @api_token = api_token
  end
  
  def read(prompt_id)
    response = http_get("/prompts/#{prompt_id}")
    
    case response.code
    when '200'
      JSON.parse(response.body)['content']
    when '404'
      raise PromptManager::PromptNotFoundError.new("Prompt '#{prompt_id}' not found")
    else
      raise PromptManager::StorageError.new("HTTP error: #{response.code}")
    end
  end
  
  def write(prompt_id, content)
    body = { content: content }.to_json
    response = http_post("/prompts/#{prompt_id}", body)
    
    response.code == '200' || response.code == '201'
  end
  
  def exist?(prompt_id)
    response = http_head("/prompts/#{prompt_id}")
    response.code == '200'
  rescue
    false
  end
  
  def delete(prompt_id)
    response = http_delete("/prompts/#{prompt_id}")
    response.code == '200' || response.code == '204'
  end
  
  def list
    response = http_get("/prompts")
    return [] unless response.code == '200'
    
    JSON.parse(response.body)['prompt_ids']
  end
  
  private
  
  def http_get(path)
    uri = URI("#{@base_url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    request = Net::HTTP::Get.new(uri)
    add_auth_header(request)
    
    http.request(request)
  end
  
  def http_post(path, body)
    uri = URI("#{@base_url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = body
    add_auth_header(request)
    
    http.request(request)
  end
  
  def add_auth_header(request)
    return unless @api_token
    request['Authorization'] = "Bearer #{@api_token}"
  end
end
```

## Adapter Registration

Register your custom adapter:

```ruby
# Global configuration
PromptManager.configure do |config|
  config.storage = CustomAdapter.new(option: 'value')
end

# Per-prompt configuration
prompt = PromptManager::Prompt.new(
  id: 'special_prompt',
  storage: CustomAdapter.new
)
```

## Error Handling

### Standard Exceptions

All adapters should raise these standard exceptions:

```ruby
# Prompt not found
raise PromptManager::PromptNotFoundError.new("Prompt 'xyz' not found")

# Storage operation failed
raise PromptManager::StorageError.new("Connection timeout")

# Configuration error
raise PromptManager::ConfigurationError.new("Invalid database URL")
```

### Error Context

Provide context in error messages:

```ruby
begin
  content = storage.read(prompt_id)
rescue => e
  raise PromptManager::StorageError.new(
    "Failed to read prompt '#{prompt_id}': #{e.message}"
  )
end
```

## Performance Considerations

### Connection Pooling

```ruby
class PooledAdapter < PromptManager::Storage::Base
  def initialize(pool_size: 10, **options)
    super(**options)
    @pool = ConnectionPool.new(size: pool_size) do
      create_connection
    end
  end
  
  def read(prompt_id)
    @pool.with { |conn| conn.read(prompt_id) }
  end
end
```

### Caching

```ruby
class CachedAdapter < PromptManager::Storage::Base
  def initialize(cache_ttl: 300, **options)
    super(**options)
    @cache = {}
    @cache_ttl = cache_ttl
  end
  
  def read(prompt_id)
    cached = @cache[prompt_id]
    if cached && (Time.current - cached[:timestamp]) < @cache_ttl
      return cached[:content]
    end
    
    content = super(prompt_id)
    @cache[prompt_id] = {
      content: content,
      timestamp: Time.current
    }
    content
  end
end
```

## Testing Adapters

### RSpec Shared Examples

```ruby
# spec/support/shared_examples/storage_adapter.rb
RSpec.shared_examples 'a storage adapter' do
  let(:prompt_id) { 'test_prompt' }
  let(:content) { 'Hello [NAME]!' }
  
  describe '#write and #read' do
    it 'stores and retrieves content' do
      expect(adapter.write(prompt_id, content)).to be true
      expect(adapter.read(prompt_id)).to eq content
    end
  end
  
  describe '#exist?' do
    it 'returns false for non-existent prompts' do
      expect(adapter.exist?('non_existent')).to be false
    end
    
    it 'returns true for existing prompts' do
      adapter.write(prompt_id, content)
      expect(adapter.exist?(prompt_id)).to be true
    end
  end
  
  describe '#delete' do
    it 'removes prompts' do
      adapter.write(prompt_id, content)
      expect(adapter.delete(prompt_id)).to be true
      expect(adapter.exist?(prompt_id)).to be false
    end
  end
  
  describe '#list' do
    it 'returns all prompt IDs' do
      adapter.write('prompt1', 'content1')
      adapter.write('prompt2', 'content2')
      
      expect(adapter.list).to contain_exactly('prompt1', 'prompt2')
    end
  end
end

# Usage in adapter specs
describe CustomAdapter do
  let(:adapter) { described_class.new(options) }
  
  include_examples 'a storage adapter'
end
```

## Best Practices

1. **Thread Safety**: Ensure adapter operations are thread-safe
2. **Error Handling**: Use standard PromptManager exceptions
3. **Resource Management**: Properly close connections and clean up resources
4. **Configuration Validation**: Validate configuration parameters in constructor
5. **Documentation**: Document all configuration options and behavior
6. **Testing**: Use shared examples to ensure consistent behavior
7. **Performance**: Consider caching and connection pooling for remote storage