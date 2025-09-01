# Custom Storage Adapters

Create custom storage adapters to integrate PromptManager with any storage system.

## Adapter Interface

All storage adapters must inherit from `PromptManager::Storage::Base` and implement the required methods:

```ruby
class CustomAdapter < PromptManager::Storage::Base
  def initialize(**options)
    # Initialize your storage connection
    super
  end
  
  def read(prompt_id)
    # Return the prompt content as a string
    # Raise PromptManager::PromptNotFoundError if not found
  end
  
  def write(prompt_id, content)
    # Save the prompt content
    # Return true on success
  end
  
  def exist?(prompt_id)
    # Return true if prompt exists
  end
  
  def delete(prompt_id) 
    # Remove the prompt
    # Return true on success
  end
  
  def list
    # Return array of all prompt IDs
  end
end
```

## Example: Redis Adapter

```ruby
require 'redis'

class RedisAdapter < PromptManager::Storage::Base
  def initialize(redis_url: 'redis://localhost:6379', key_prefix: 'prompts:', **options)
    @redis = Redis.new(url: redis_url)
    @key_prefix = key_prefix
    super(**options)
  end
  
  def read(prompt_id)
    content = @redis.get(redis_key(prompt_id))
    raise PromptManager::PromptNotFoundError.new("Prompt '#{prompt_id}' not found") unless content
    content
  end
  
  def write(prompt_id, content)
    @redis.set(redis_key(prompt_id), content)
    true
  end
  
  def exist?(prompt_id)
    @redis.exists?(redis_key(prompt_id)) > 0
  end
  
  def delete(prompt_id)
    @redis.del(redis_key(prompt_id)) > 0
  end
  
  def list
    keys = @redis.keys("#{@key_prefix}*")
    keys.map { |key| key.sub(@key_prefix, '') }
  end
  
  private
  
  def redis_key(prompt_id)
    "#{@key_prefix}#{prompt_id}"
  end
end

# Configure PromptManager to use Redis
PromptManager.configure do |config|
  config.storage = RedisAdapter.new(
    redis_url: ENV['REDIS_URL'],
    key_prefix: 'myapp:prompts:'
  )
end
```

## Example: S3 Adapter

```ruby
require 'aws-sdk-s3'

class S3Adapter < PromptManager::Storage::Base
  def initialize(bucket:, region: 'us-east-1', key_prefix: 'prompts/', **options)
    @bucket = bucket
    @key_prefix = key_prefix
    @s3 = Aws::S3::Client.new(region: region)
    super(**options)
  end
  
  def read(prompt_id)
    response = @s3.get_object(
      bucket: @bucket,
      key: s3_key(prompt_id)
    )
    response.body.read
  rescue Aws::S3::Errors::NoSuchKey
    raise PromptManager::PromptNotFoundError.new("Prompt '#{prompt_id}' not found")
  end
  
  def write(prompt_id, content)
    @s3.put_object(
      bucket: @bucket,
      key: s3_key(prompt_id),
      body: content,
      content_type: 'text/plain'
    )
    true
  end
  
  def exist?(prompt_id)
    @s3.head_object(bucket: @bucket, key: s3_key(prompt_id))
    true
  rescue Aws::S3::Errors::NotFound
    false
  end
  
  def delete(prompt_id)
    @s3.delete_object(bucket: @bucket, key: s3_key(prompt_id))
    true
  end
  
  def list
    response = @s3.list_objects_v2(
      bucket: @bucket,
      prefix: @key_prefix
    )
    
    response.contents.map do |object|
      object.key.sub(@key_prefix, '')
    end
  end
  
  private
  
  def s3_key(prompt_id)
    "#{@key_prefix}#{prompt_id}.txt"
  end
end
```

## Best Practices

1. **Error Handling**: Always raise appropriate exceptions
2. **Connection Management**: Handle connection failures gracefully  
3. **Performance**: Implement connection pooling where appropriate
4. **Security**: Use proper authentication and encryption
5. **Testing**: Write comprehensive tests for your adapter
6. **Documentation**: Document configuration options and requirements

## Configuration

Register your custom adapter:

```ruby
PromptManager.configure do |config|
  config.storage = CustomAdapter.new(
    # Your adapter configuration
  )
end
```