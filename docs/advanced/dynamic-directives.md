# Dynamic Directives

Dynamic directives allow you to create sophisticated, runtime-configurable prompt processing behaviors that go beyond static `//include` statements.

## Overview

Dynamic directives are custom processing instructions that can modify prompt content based on runtime conditions, external data sources, user context, and complex business logic.

## Creating Dynamic Directives

### Basic Dynamic Directive

```ruby
PromptManager.configure do |config|
  config.directive_processor.register_directive('current_time') do |args, context|
    format = args.strip.empty? ? '%Y-%m-%d %H:%M:%S' : args.strip
    Time.current.strftime(format)
  end
end
```

```text
# Usage in prompts:
Generated at: //current_time
Custom format: //current_time %B %d, %Y at %I:%M %p
```

### Context-Aware Directives

```ruby
config.directive_processor.register_directive('user_greeting') do |args, context|
  user = context.dig(:parameters, :user)
  return 'Hello there!' unless user
  
  time_of_day = Time.current.hour
  greeting = case time_of_day
             when 0..11 then 'Good morning'
             when 12..17 then 'Good afternoon'
             else 'Good evening'
             end
  
  "#{greeting}, #{user[:name]}!"
end
```

## Advanced Directive Patterns

### Data Loading Directives

```ruby
config.directive_processor.register_directive('load_user_data') do |user_id, context|
  begin
    user = UserService.find(user_id)
    context[:loaded_user] = user
    
    # Return user summary
    <<~USER_INFO
    User: #{user.name}
    Email: #{user.email}
    Account Type: #{user.account_type}
    USER_INFO
  rescue UserNotFoundError
    'User information unavailable'
  end
end
```

### API Integration Directives

```ruby
config.directive_processor.register_directive('weather') do |location, context|
  begin
    response = HTTParty.get(
      'https://api.weather.example.com/current',
      query: {
        location: location,
        api_key: ENV['WEATHER_API_KEY']
      }
    )
    
    if response.success?
      data = response.parsed_response
      "Weather in #{location}: #{data['temperature']}°F, #{data['condition']}"
    else
      'Weather information unavailable'
    end
  rescue => e
    Rails.logger.error "Weather API error: #{e.message}"
    'Weather service temporarily unavailable'
  end
end
```

### Database Query Directives

```ruby
config.directive_processor.register_directive('recent_orders') do |user_id, context|
  user = User.find(user_id)
  recent_orders = user.orders.recent.limit(5)
  
  if recent_orders.any?
    orders_list = recent_orders.map do |order|
      "- Order ##{order.id}: #{order.total_formatted} (#{order.status})"
    end.join("\n")
    
    "Your recent orders:\n#{orders_list}"
  else
    'You have no recent orders.'
  end
rescue ActiveRecord::RecordNotFound
  'User not found'
end
```

## Conditional Logic Directives

### IF/ELSE/ENDIF Directive System

```ruby
class ConditionalDirectiveProcessor
  def self.register_conditionals(processor)
    processor.register_directive('if') do |condition, context|
      context[:if_stack] ||= []
      
      result = evaluate_condition(condition, context)
      context[:if_stack].push({
        condition_met: result,
        in_else: false,
        content: ''
      })
      
      '' # Don't output anything for the if directive itself
    end
    
    processor.register_directive('else') do |args, context|
      return '' unless context[:if_stack]&.any?
      
      current_if = context[:if_stack].last
      current_if[:in_else] = true
      
      '' # Don't output anything for the else directive
    end
    
    processor.register_directive('endif') do |args, context|
      return '' unless context[:if_stack]&.any?
      
      if_block = context[:if_stack].pop
      
      # Process the accumulated content based on conditions
      if (if_block[:condition_met] && !if_block[:in_else]) ||
         (!if_block[:condition_met] && if_block[:in_else])
        processor.process(if_block[:content], context)
      else
        ''
      end
    end
  end
  
  def self.evaluate_condition(condition, context)
    # Simple condition evaluation
    # In production, use a proper expression evaluator
    case condition.strip
    when /\[(\w+)\]\s*(==|!=|>|<|>=|<=)\s*(.+)/
      param_name = Regexp.last_match(1).downcase.to_sym
      operator = Regexp.last_match(2)
      expected_value = Regexp.last_match(3).strip.gsub(/['"]/, '')
      
      actual_value = context.dig(:parameters, param_name).to_s
      
      case operator
      when '==' then actual_value == expected_value
      when '!=' then actual_value != expected_value
      when '>' then actual_value.to_f > expected_value.to_f
      when '<' then actual_value.to_f < expected_value.to_f
      when '>=' then actual_value.to_f >= expected_value.to_f
      when '<=' then actual_value.to_f <= expected_value.to_f
      end
    else
      false
    end
  end
end

# Register the conditional directives
ConditionalDirectiveProcessor.register_conditionals(
  PromptManager.configuration.directive_processor
)
```

```text
# Usage in prompts:
//if [USER_TYPE] == 'premium'
🌟 Welcome to Premium features!
//else
Upgrade to Premium for additional benefits.
//endif

//if [ORDER_TOTAL] >= 100
🚚 Free shipping applied!
//endif
```

### Loop Directives

```ruby
config.directive_processor.register_directive('foreach') do |args, context|
  array_name, template = args.split(':', 2)
  array_data = context.dig(:parameters, array_name.strip.to_sym) || []
  
  array_data.map.with_index do |item, index|
    # Create item context
    item_context = context.deep_dup
    item_context[:parameters].merge!({
      item: item,
      item_index: index,
      is_first: index == 0,
      is_last: index == array_data.length - 1,
      total_count: array_data.length
    })
    
    # Process template with item context
    processed_template = template.gsub(/\[ITEM\.(\w+)\]/i) do |match|
      property = Regexp.last_match(1).downcase
      item.is_a?(Hash) ? item[property.to_sym] : item.send(property)
    end
    
    PromptManager::DirectiveProcessor.new.process(processed_template, item_context)
  end.join("\n")
end
```

```text
# Usage in prompts:
Your order items:
//foreach order_items: - [ITEM.name]: $[ITEM.price] (Qty: [ITEM.quantity])

//foreach products: 
**[ITEM.name]** - $[ITEM.price]
//if [ITEM.on_sale] == 'true'
🏷️ ON SALE!
//endif
```

## Template System Directives

### Layout System

```ruby
class LayoutDirectiveProcessor
  def self.register_layout_directives(processor)
    processor.register_directive('layout') do |layout_name, context|
      layout_content = processor.storage.read("layouts/#{layout_name}")
      context[:current_layout] = layout_content
      context[:sections] ||= {}
      '' # Layout directive doesn't output content directly
    end
    
    processor.register_directive('section') do |args, context|
      section_name, content = args.split(':', 2)
      context[:sections] ||= {}
      context[:sections][section_name.strip] = content.strip
      '' # Section directive stores content for later use
    end
    
    processor.register_directive('yield') do |section_name, context|
      section_content = context.dig(:sections, section_name.strip) || ''
      processor.process(section_content, context)
    end
    
    processor.register_directive('render_layout') do |args, context|
      return '' unless context[:current_layout]
      
      processor.process(context[:current_layout], context)
    end
  end
end

LayoutDirectiveProcessor.register_layout_directives(
  PromptManager.configuration.directive_processor
)
```

```text
# child_template.txt:
//layout email_layout
//section title: Important Account Update
//section content: Your account settings have been updated successfully.
//render_layout

# layouts/email_layout.txt:
Subject: //yield title

Dear [CUSTOMER_NAME],

//yield content

Best regards,
The Support Team
```

### Component System

```ruby
config.directive_processor.register_directive('component') do |args, context|
  component_name, props_str = args.split(':', 2)
  
  # Parse component props
  props = {}
  if props_str
    props_str.scan(/(\w+)="([^"]*)"/) do |key, value|
      props[key.to_sym] = value
    end
  end
  
  # Load component template
  component_template = processor.storage.read("components/#{component_name}")
  
  # Create component context
  component_context = context.deep_dup
  component_context[:parameters].merge!(props)
  
  # Render component
  processor.process(component_template, component_context)
rescue PromptManager::PromptNotFoundError
  "<!-- Component '#{component_name}' not found -->"
end
```

```text
# Using components:
//component button: text="Click Here" url="https://example.com" style="primary"
//component user_card: name="[USER_NAME]" email="[USER_EMAIL]"

# components/button.txt:
[Click here]([URL]) <!-- [TEXT] -->

# components/user_card.txt:
**[NAME]**
Email: [EMAIL]
```

## External Service Integration

### CRM Integration Directive

```ruby
config.directive_processor.register_directive('crm_data') do |args, context|
  data_type, customer_id = args.split(':', 2)
  
  case data_type.strip
  when 'customer_info'
    customer = CRMService.get_customer(customer_id)
    <<~INFO
    Customer: #{customer.name}
    Account Value: #{customer.lifetime_value}
    Support Tier: #{customer.support_tier}
    INFO
    
  when 'recent_interactions'
    interactions = CRMService.get_recent_interactions(customer_id, limit: 5)
    interactions.map do |interaction|
      "- #{interaction.date}: #{interaction.type} - #{interaction.summary}"
    end.join("\n")
    
  else
    'Unknown CRM data type'
  end
rescue => e
  Rails.logger.error "CRM integration error: #{e.message}"
  'CRM data temporarily unavailable'
end
```

### Analytics Directive

```ruby
config.directive_processor.register_directive('analytics') do |args, context|
  metric_type, time_period = args.split(':', 2)
  time_period ||= '30d'
  
  case metric_type.strip
  when 'user_activity'
    user_id = context.dig(:parameters, :user_id)
    activity = AnalyticsService.get_user_activity(user_id, time_period)
    "Active #{activity[:active_days]} days in the last #{time_period}"
    
  when 'feature_usage'
    feature_usage = AnalyticsService.get_feature_usage(time_period)
    top_features = feature_usage.first(3)
    "Top features: #{top_features.map(&:name).join(', ')}"
    
  else
    'Unknown analytics metric'
  end
end
```

## Performance Optimization

### Caching Dynamic Directives

```ruby
class CachedDirectiveProcessor < PromptManager::DirectiveProcessor
  def initialize(**options)
    super(**options)
    @directive_cache = Rails.cache
  end
  
  def register_cached_directive(name, cache_ttl: 300, &handler)
    cached_handler = lambda do |args, context|
      cache_key = generate_cache_key(name, args, context)
      
      @directive_cache.fetch(cache_key, expires_in: cache_ttl) do
        handler.call(args, context)
      end
    end
    
    register_directive(name, &cached_handler)
  end
  
  private
  
  def generate_cache_key(directive_name, args, context)
    relevant_params = context[:parameters].slice(:user_id, :tenant_id)
    "directive:#{directive_name}:#{args}:#{relevant_params.hash}"
  end
end
```

### Async Directive Processing

```ruby
config.directive_processor.register_directive('async_load') do |args, context|
  data_source = args.strip
  cache_key = "async_data:#{data_source}:#{context[:parameters][:user_id]}"
  
  # Try to get cached result first
  cached_result = Rails.cache.read(cache_key)
  return cached_result if cached_result
  
  # Start async job if not cached
  AsyncDataLoadJob.perform_later(data_source, cache_key, context[:parameters])
  
  # Return placeholder
  "Loading #{data_source} data..."
end

class AsyncDataLoadJob < ApplicationJob
  def perform(data_source, cache_key, parameters)
    result = load_data_from_source(data_source, parameters)
    Rails.cache.write(cache_key, result, expires_in: 1.hour)
  end
end
```

## Testing Dynamic Directives

### RSpec Examples

```ruby
describe 'Dynamic Directives' do
  let(:processor) { PromptManager::DirectiveProcessor.new(storage: storage) }
  let(:storage) { instance_double(PromptManager::Storage::Base) }
  
  before do
    processor.register_directive('test_directive') do |args, context|
      "processed: #{args} with #{context.dig(:parameters, :test_param)}"
    end
  end
  
  it 'processes directive with context' do
    content = "//test_directive hello world"
    context = { parameters: { test_param: 'value' } }
    
    result = processor.process(content, context)
    expect(result).to eq "processed: hello world with value"
  end
  
  it 'handles directive errors' do
    processor.register_directive('error_directive') do |args, context|
      raise StandardError, 'test error'
    end
    
    expect {
      processor.process("//error_directive test")
    }.to raise_error(PromptManager::DirectiveProcessingError)
  end
end
```

### Integration Tests

```ruby
describe 'Dynamic Directive Integration' do
  it 'processes complex directive chains' do
    storage = PromptManager::Storage::FileSystemAdapter.new(prompts_dir: 'spec/fixtures')
    processor = PromptManager::DirectiveProcessor.new(storage: storage)
    
    # Register test directives
    processor.register_directive('if') { |condition, context| ... }
    processor.register_directive('foreach') { |args, context| ... }
    
    prompt_content = <<~PROMPT
    //if [USER_TYPE] == 'premium'
    Premium Features:
    //foreach features: - [ITEM.name]: [ITEM.description]
    //endif
    PROMPT
    
    result = processor.process(prompt_content, {
      parameters: {
        user_type: 'premium',
        features: [
          { name: 'Feature 1', description: 'Description 1' },
          { name: 'Feature 2', description: 'Description 2' }
        ]
      }
    })
    
    expect(result).to include('Feature 1: Description 1')
    expect(result).to include('Feature 2: Description 2')
  end
end
```

## Best Practices

1. **Error Handling**: Always handle errors gracefully in directive processors
2. **Performance**: Cache expensive operations and use async processing when appropriate
3. **Security**: Validate and sanitize all directive arguments
4. **Context Isolation**: Be careful when modifying context to avoid side effects
5. **Documentation**: Document directive syntax, parameters, and behavior
6. **Testing**: Write comprehensive tests including error cases
7. **Naming**: Use clear, descriptive names that indicate the directive's purpose
8. **Resource Management**: Clean up resources and connections properly