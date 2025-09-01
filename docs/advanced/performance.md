# Performance Optimization

This guide covers techniques and best practices for optimizing PromptManager performance in production environments.

## Caching Strategies

### Prompt Content Caching

```ruby
# Enable built-in caching
PromptManager.configure do |config|
  config.cache_prompts = true
  config.cache_ttl = 3600  # 1 hour
  config.cache_store = ActiveSupport::Cache::RedisStore.new(
    url: ENV['REDIS_URL'],
    namespace: 'prompt_manager'
  )
end
```

### Custom Caching Layer

```ruby
class CachedPromptManager
  def self.render(prompt_id, parameters = {}, cache_options = {})
    cache_key = generate_cache_key(prompt_id, parameters)
    
    Rails.cache.fetch(cache_key, cache_options) do
      prompt = PromptManager::Prompt.new(id: prompt_id)
      prompt.render(parameters)
    end
  end
  
  def self.invalidate_cache(prompt_id, parameters = nil)
    if parameters
      cache_key = generate_cache_key(prompt_id, parameters)
      Rails.cache.delete(cache_key)
    else
      # Invalidate all cached versions of this prompt
      Rails.cache.delete_matched("prompt:#{prompt_id}:*")
    end
  end
  
  private
  
  def self.generate_cache_key(prompt_id, parameters)
    param_hash = Digest::MD5.hexdigest(parameters.to_json)
    "prompt:#{prompt_id}:#{param_hash}"
  end
end

# Usage
result = CachedPromptManager.render('welcome_email', { name: 'John' }, expires_in: 30.minutes)
```

### Multi-level Caching

```ruby
class HierarchicalPromptCache
  def initialize
    @l1_cache = ActiveSupport::Cache::MemoryStore.new(size: 100) # Fast, small
    @l2_cache = Rails.cache # Redis, larger but slower
  end
  
  def fetch(key, options = {}, &block)
    # Try L1 cache first
    result = @l1_cache.read(key)
    return result if result
    
    # Try L2 cache
    result = @l2_cache.fetch(key, options, &block)
    
    # Store in L1 cache for next time
    @l1_cache.write(key, result, expires_in: 5.minutes) if result
    
    result
  end
  
  def invalidate(key_pattern)
    @l1_cache.clear
    @l2_cache.delete_matched(key_pattern)
  end
end
```

## Storage Optimization

### Connection Pooling

```ruby
class PooledDatabaseAdapter < PromptManager::Storage::ActiveRecordAdapter
  def initialize(pool_size: 10, **options)
    super(**options)
    @connection_pool = ConnectionPool.new(size: pool_size) do
      model_class.connection_pool.checkout
    end
  end
  
  def read(prompt_id)
    @connection_pool.with do |connection|
      result = connection.exec_query(
        "SELECT content FROM prompts WHERE prompt_id = ?",
        'PromptManager::Read',
        [prompt_id]
      )
      
      raise PromptNotFoundError unless result.any?
      result.first['content']
    end
  end
  
  def write(prompt_id, content)
    @connection_pool.with do |connection|
      connection.exec_insert(
        "INSERT INTO prompts (prompt_id, content, updated_at) VALUES (?, ?, ?) " \
        "ON CONFLICT (prompt_id) DO UPDATE SET content = ?, updated_at = ?",
        'PromptManager::Write',
        [prompt_id, content, Time.current, content, Time.current]
      )
    end
    true
  end
end
```

### Bulk Operations

```ruby
class BulkPromptOperations
  def self.bulk_render(prompt_configs, batch_size: 100)
    results = {}
    
    prompt_configs.each_slice(batch_size) do |batch|
      # Pre-load all prompts in the batch
      prompt_contents = preload_prompts(batch.map { |config| config[:prompt_id] })
      
      # Process batch in parallel
      batch_results = Parallel.map(batch, in_threads: 4) do |config|
        begin
          content = prompt_contents[config[:prompt_id]]
          next unless content
          
          processor = PromptManager::DirectiveProcessor.new
          result = processor.process(content, config[:parameters])
          
          [config[:prompt_id], { success: true, result: result }]
        rescue => e
          [config[:prompt_id], { success: false, error: e.message }]
        end
      end.compact
      
      batch_results.each do |prompt_id, result|
        results[prompt_id] = result
      end
    end
    
    results
  end
  
  private
  
  def self.preload_prompts(prompt_ids)
    # Batch load all prompts at once
    if PromptManager.storage.respond_to?(:bulk_read)
      PromptManager.storage.bulk_read(prompt_ids)
    else
      prompt_ids.each_with_object({}) do |id, hash|
        begin
          hash[id] = PromptManager.storage.read(id)
        rescue PromptNotFoundError
          # Skip missing prompts
        end
      end
    end
  end
end

# Usage
configs = [
  { prompt_id: 'welcome', parameters: { name: 'Alice' } },
  { prompt_id: 'welcome', parameters: { name: 'Bob' } },
  { prompt_id: 'reminder', parameters: { task: 'Meeting' } }
]

results = BulkPromptOperations.bulk_render(configs)
```

## Directive Processing Optimization

### Lazy Evaluation

```ruby
class LazyDirectiveProcessor < PromptManager::DirectiveProcessor
  def process(content, context = {})
    # Only process directives that are actually needed
    lazy_content = LazyContent.new(content, context)
    lazy_content.to_s
  end
end

class LazyContent
  def initialize(content, context)
    @content = content
    @context = context
    @processed = false
    @result = nil
  end
  
  def to_s
    return @result if @processed
    
    # Process only when needed
    @result = process_directives
    @processed = true
    @result
  end
  
  private
  
  def process_directives
    # Only process directives that appear in the content
    directive_pattern = %r{^//(\w+)\s+(.*)$}
    
    @content.gsub(directive_pattern) do |match|
      directive_name = Regexp.last_match(1)
      directive_args = Regexp.last_match(2)
      
      # Skip processing if directive handler doesn't exist
      next match unless directive_handlers.key?(directive_name)
      
      # Process directive
      handler = directive_handlers[directive_name]
      handler.call(directive_args, @context)
    end
  end
end
```

### Directive Compilation

```ruby
class CompiledDirectiveProcessor
  def initialize
    @compiled_templates = {}
  end
  
  def compile(content)
    template_id = Digest::MD5.hexdigest(content)
    
    @compiled_templates[template_id] ||= compile_template(content)
  end
  
  def render(template_id, context)
    compiled_template = @compiled_templates[template_id]
    return nil unless compiled_template
    
    compiled_template.call(context)
  end
  
  private
  
  def compile_template(content)
    # Pre-compile template into executable code
    ruby_code = convert_to_ruby(content)
    
    # Create a proc that can be called with context
    eval("lambda { |context| #{ruby_code} }")
  end
  
  def convert_to_ruby(content)
    # Convert directive syntax to Ruby code
    content.gsub(%r{//include\s+(.+)}) do |match|
      file_path = Regexp.last_match(1).strip
      %{PromptManager.storage.read("#{file_path}")}
    end.gsub(/\[(\w+)\]/) do |match|
      param_name = Regexp.last_match(1).downcase
      %{context[:parameters][:#{param_name}]}
    end
  end
end
```

## Memory Management

### Memory-Efficient Prompt Loading

```ruby
class StreamingPromptProcessor
  def process_large_prompt(prompt_id, parameters = {})
    prompt_file = PromptManager.storage.file_path(prompt_id)
    
    Enumerator.new do |yielder|
      File.foreach(prompt_file) do |line|
        processed_line = process_line(line, parameters)
        yielder << processed_line unless processed_line.empty?
      end
    end
  end
  
  private
  
  def process_line(line, parameters)
    # Process parameters in this line
    line.gsub(/\[(\w+)\]/) do |match|
      param_name = Regexp.last_match(1).downcase.to_sym
      parameters[param_name] || match
    end
  end
end

# Usage for large prompts
processor = StreamingPromptProcessor.new
prompt_stream = processor.process_large_prompt('huge_prompt', user_id: 123)

prompt_stream.each do |line|
  # Process line by line without loading entire prompt into memory
  output_stream.puts line
end
```

### Object Pool Pattern

```ruby
class PromptProcessorPool
  def initialize(size: 10)
    @pool = Queue.new
    @size = size
    
    size.times do
      @pool << PromptManager::DirectiveProcessor.new
    end
  end
  
  def with_processor
    processor = @pool.pop
    begin
      yield processor
    ensure
      # Reset processor state
      processor.reset_state if processor.respond_to?(:reset_state)
      @pool << processor
    end
  end
end

# Global pool
PROCESSOR_POOL = PromptProcessorPool.new(size: 20)

# Usage
PROCESSOR_POOL.with_processor do |processor|
  result = processor.process(content, context)
end
```

## Database Query Optimization

### Query Optimization for ActiveRecord Adapter

```ruby
class OptimizedActiveRecordAdapter < PromptManager::Storage::ActiveRecordAdapter
  def bulk_read(prompt_ids)
    # Single query instead of N+1
    prompts = model_class.where(id_column => prompt_ids)
                        .pluck(id_column, content_column)
                        .to_h
    
    # Ensure all requested IDs are present
    missing_ids = prompt_ids - prompts.keys
    missing_ids.each { |id| prompts[id] = nil }
    
    prompts
  end
  
  def read_with_metadata(prompt_id)
    # Fetch prompt and metadata in single query
    prompt = model_class.select(:id, :content, :metadata, :updated_at)
                       .find_by(id_column => prompt_id)
    
    raise PromptNotFoundError unless prompt
    
    {
      content: prompt.send(content_column),
      metadata: prompt.metadata,
      last_modified: prompt.updated_at
    }
  end
  
  def frequently_used_prompts(limit: 100)
    # Cache frequently accessed prompts
    model_class.joins(:usage_logs)
              .group(id_column)
              .order('COUNT(usage_logs.id) DESC')
              .limit(limit)
              .pluck(id_column, content_column)
              .to_h
  end
end
```

### Index Optimization

```sql
-- Optimize database indexes for prompt queries

-- Primary lookup index
CREATE INDEX CONCURRENTLY idx_prompts_id_active 
ON prompts(prompt_id) WHERE active = true;

-- Content search index (PostgreSQL)
CREATE INDEX CONCURRENTLY idx_prompts_content_gin 
ON prompts USING gin(to_tsvector('english', content));

-- Metadata search index (PostgreSQL with JSONB)
CREATE INDEX CONCURRENTLY idx_prompts_metadata_gin 
ON prompts USING gin(metadata);

-- Usage-based queries
CREATE INDEX CONCURRENTLY idx_prompts_usage_updated 
ON prompts(usage_count DESC, updated_at DESC);

-- Composite index for filtered queries
CREATE INDEX CONCURRENTLY idx_prompts_category_status_updated 
ON prompts(category, status, updated_at DESC);
```

## Monitoring and Profiling

### Performance Monitoring

```ruby
class PromptPerformanceMonitor
  def self.monitor_render(prompt_id, parameters = {})
    start_time = Time.current
    memory_before = get_memory_usage
    
    begin
      result = yield
      
      duration = Time.current - start_time
      memory_after = get_memory_usage
      memory_used = memory_after - memory_before
      
      log_performance_metrics(prompt_id, {
        duration: duration,
        memory_used: memory_used,
        parameters_count: parameters.size,
        result_size: result.bytesize,
        success: true
      })
      
      result
    rescue => e
      duration = Time.current - start_time
      
      log_performance_metrics(prompt_id, {
        duration: duration,
        error: e.class.name,
        success: false
      })
      
      raise e
    end
  end
  
  private
  
  def self.get_memory_usage
    GC.stat[:heap_allocated_pages] * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE]
  end
  
  def self.log_performance_metrics(prompt_id, metrics)
    Rails.logger.info "PromptManager Performance: #{prompt_id}", metrics
    
    # Send to monitoring service
    if defined?(StatsD)
      StatsD.histogram('prompt_manager.render_duration', metrics[:duration])
      StatsD.histogram('prompt_manager.memory_usage', metrics[:memory_used]) if metrics[:memory_used]
      StatsD.increment('prompt_manager.renders', tags: ["success:#{metrics[:success]}"])
    end
  end
end

# Usage
result = PromptPerformanceMonitor.monitor_render('welcome_email', name: 'John') do
  prompt = PromptManager::Prompt.new(id: 'welcome_email')
  prompt.render(name: 'John')
end
```

### Custom Profiling

```ruby
class PromptProfiler
  def self.profile_render(prompt_id, parameters = {})
    profiler = RubyProf.profile do
      prompt = PromptManager::Prompt.new(id: prompt_id)
      prompt.render(parameters)
    end
    
    # Generate reports
    printer = RubyProf::GraphHtmlPrinter.new(profiler)
    File.open("tmp/profile_#{prompt_id}_#{Time.current.to_i}.html", 'w') do |file|
      printer.print(file)
    end
  end
  
  def self.benchmark_operations(iterations: 100)
    Benchmark.bmbm do |x|
      x.report("File read:") do
        iterations.times { PromptManager.storage.read('test_prompt') }
      end
      
      x.report("Template render:") do
        prompt = PromptManager::Prompt.new(id: 'test_prompt')
        iterations.times { prompt.render(name: 'test') }
      end
      
      x.report("Cached render:") do
        iterations.times { CachedPromptManager.render('test_prompt', name: 'test') }
      end
    end
  end
end
```

## Production Deployment Optimization

### Preloading and Warmup

```ruby
class PromptPreloader
  def self.preload_critical_prompts
    critical_prompts = %w[
      welcome_email
      password_reset
      order_confirmation
      error_notification
    ]
    
    critical_prompts.each do |prompt_id|
      begin
        prompt = PromptManager::Prompt.new(id: prompt_id)
        
        # Preload into cache
        CachedPromptManager.render(prompt_id, {}, expires_in: 1.hour)
        
        Rails.logger.info "Preloaded prompt: #{prompt_id}"
      rescue => e
        Rails.logger.error "Failed to preload #{prompt_id}: #{e.message}"
      end
    end
  end
  
  def self.warmup_processor_pool
    # Initialize processor pool
    PROCESSOR_POOL.with_processor do |processor|
      processor.process("//include test\nWarmup content [TEST]", 
                       parameters: { test: 'value' })
    end
    
    Rails.logger.info "Processor pool warmed up"
  end
end

# In Rails initializer or deployment script
Rails.application.config.after_initialize do
  PromptPreloader.preload_critical_prompts
  PromptPreloader.warmup_processor_pool
end
```

### Configuration for Production

```ruby
# config/environments/production.rb
PromptManager.configure do |config|
  # Use optimized storage adapter
  config.storage = OptimizedActiveRecordAdapter.new
  
  # Enable aggressive caching
  config.cache_prompts = true
  config.cache_ttl = 3600  # 1 hour
  config.cache_store = ActiveSupport::Cache::RedisStore.new(
    url: ENV['REDIS_URL'],
    pool_size: 10,
    pool_timeout: 5
  )
  
  # Optimize processing
  config.max_include_depth = 5  # Reduce for performance
  config.directive_timeout = 10  # Shorter timeout
  
  # Error handling
  config.raise_on_missing_prompts = false
  config.error_handler = ->(error, context) {
    Rails.logger.error "Prompt error: #{error.message}"
    ErrorTracker.notify(error, context)
    'Content temporarily unavailable'
  }
end
```

## Best Practices Summary

1. **Cache Aggressively**: Cache rendered prompts and frequently accessed content
2. **Batch Operations**: Process multiple prompts together when possible
3. **Monitor Performance**: Track render times, memory usage, and error rates
4. **Optimize Queries**: Use proper indexes and minimize database roundtrips
5. **Pool Resources**: Reuse expensive objects like processors and connections
6. **Profile Regularly**: Identify bottlenecks in production workloads
7. **Preload Critical Content**: Warm up caches with important prompts
8. **Handle Errors Gracefully**: Provide fallbacks when performance degrades