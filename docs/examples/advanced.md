# Advanced Examples

This section demonstrates advanced usage patterns and real-world scenarios with PromptManager.

## Complex Parameter Structures

### Nested Object Rendering

```ruby
# prompts/user_profile.txt
User Profile Report
===================

Name: [USER.PERSONAL.FIRST_NAME] [USER.PERSONAL.LAST_NAME]
Email: [USER.CONTACT.EMAIL]
Phone: [USER.CONTACT.PHONE]

Address:
[USER.ADDRESS.STREET]
[USER.ADDRESS.CITY], [USER.ADDRESS.STATE] [USER.ADDRESS.ZIP]

Account Status: [USER.ACCOUNT.STATUS]
Member Since: [USER.ACCOUNT.CREATED_DATE]
Last Login: [USER.ACCOUNT.LAST_LOGIN]

Preferences:
- Newsletter: [USER.PREFERENCES.NEWSLETTER]
- Notifications: [USER.PREFERENCES.NOTIFICATIONS]
```

```ruby
# Usage
prompt = PromptManager::Prompt.new(id: 'user_profile')

user_data = {
  user: {
    personal: {
      first_name: 'John',
      last_name: 'Doe'
    },
    contact: {
      email: 'john@example.com',
      phone: '555-0123'
    },
    address: {
      street: '123 Main St',
      city: 'Springfield',
      state: 'IL',
      zip: '62701'
    },
    account: {
      status: 'Active',
      created_date: '2023-01-15',
      last_login: '2024-01-20'
    },
    preferences: {
      newsletter: 'Enabled',
      notifications: 'Email + SMS'
    }
  }
}

report = prompt.render(user_data)
```

## Dynamic Content with ERB

### Conditional Content Generation

```ruby
# prompts/order_confirmation.txt
<%= erb_flag = true %>

Order Confirmation #[ORDER_ID]
==============================

Dear [CUSTOMER_NAME],

<% if '[ORDER_STATUS]' == 'express' %>
🚀 EXPRESS ORDER - Expected delivery: <%= Date.parse('[ORDER_DATE]') + 1 %>
<% elsif '[ORDER_STATUS]' == 'standard' %>
📦 STANDARD ORDER - Expected delivery: <%= Date.parse('[ORDER_DATE]') + 5 %>
<% else %>
📬 ECONOMY ORDER - Expected delivery: <%= Date.parse('[ORDER_DATE]') + 10 %>
<% end %>

Items Ordered:
<% '[ITEMS]'.split(',').each_with_index do |item, index| %>
<%= index + 1 %>. <%= item.strip %>
<% end %>

<% total = '[TOTAL]'.to_f %>
Subtotal: $<%= sprintf('%.2f', total * 0.9) %>
Tax: $<%= sprintf('%.2f', total * 0.1) %>
Total: $<%= sprintf('%.2f', total) %>

<% if total > 100 %>
🎉 You saved $<%= sprintf('%.2f', total * 0.05) %> with free shipping!
<% end %>

Track your order: [TRACKING_URL]

Thank you for your business!
```

```ruby
prompt = PromptManager::Prompt.new(id: 'order_confirmation', erb_flag: true)

confirmation = prompt.render(
  order_id: 'ORD-2024-001',
  customer_name: 'Alice Johnson',
  order_status: 'express',
  order_date: '2024-01-15',
  items: 'Laptop Pro, Wireless Mouse, USB-C Hub',
  total: 1299.99,
  tracking_url: 'https://track.example.com/ORD-2024-001'
)
```

### Dynamic Loop Generation

```ruby
# prompts/product_catalog.txt
<%= erb_flag = true %>

Product Catalog - [CATEGORY]
============================

<% products = JSON.parse('[PRODUCTS_JSON]') %>
<% products.each do |product| %>
**<%= product['name'] %>**
Price: $<%= product['price'] %>
<% if product['sale_price'] %>
🏷️ SALE PRICE: $<%= product['sale_price'] %> (Save $<%= product['price'] - product['sale_price'] %>)
<% end %>
Rating: <%= '⭐' * product['rating'] %>
<%= product['description'] %>

---
<% end %>

Total Products: <%= products.length %>
Average Price: $<%= sprintf('%.2f', products.sum { |p| p['sale_price'] || p['price'] } / products.length) %>
```

```ruby
products_data = [
  { name: 'Laptop Pro', price: 1299.99, sale_price: 999.99, rating: 5, description: 'High-performance laptop' },
  { name: 'Wireless Mouse', price: 49.99, rating: 4, description: 'Ergonomic wireless mouse' },
  { name: 'USB-C Hub', price: 79.99, sale_price: 59.99, rating: 4, description: '7-in-1 connectivity hub' }
]

prompt = PromptManager::Prompt.new(id: 'product_catalog', erb_flag: true)
catalog = prompt.render(
  category: 'Electronics',
  products_json: products_data.to_json
)
```

## Advanced Directive Usage

### Hierarchical Template System

```ruby
# prompts/layouts/base.txt
//include headers/company_header.txt

[CONTENT]

//include footers/standard_footer.txt

# prompts/layouts/email.txt  
//include layouts/base.txt

Email Settings:
- Unsubscribe: [UNSUBSCRIBE_URL]
- Update Preferences: [PREFERENCES_URL]

# prompts/headers/company_header.txt
[COMPANY_NAME] - [DEPARTMENT]
Customer Service Portal
Generated: <%= Date.today.strftime('%B %d, %Y') %>

# prompts/footers/standard_footer.txt
--
This message was generated automatically.
For assistance, contact support@[COMPANY_DOMAIN]
```

```ruby
# prompts/customer_notification.txt
//include layouts/email.txt

Dear [CUSTOMER_NAME],

Your account status has been updated to: [STATUS]

<% if '[STATUS]' == 'premium' %>
🌟 Welcome to Premium! You now have access to:
- Priority support
- Advanced features  
- Exclusive content
<% end %>

Best regards,
The [COMPANY_NAME] Team
```

### Dynamic Template Selection

```ruby
# prompts/invoice_template.txt
<%= erb_flag = true %>

<% template_type = '[TEMPLATE_TYPE]' || 'standard' %>
//include templates/invoice_<%= template_type %>.txt

Invoice #[INVOICE_ID]
Amount: $[AMOUNT]
Due Date: [DUE_DATE]

# prompts/templates/invoice_standard.txt
Standard Invoice Template
=========================
Payment terms: Net 30

# prompts/templates/invoice_premium.txt  
Premium Invoice Template
========================
⭐ Priority Processing
Payment terms: Net 15
```

## Environment Integration

### System Information Prompts

```ruby
# prompts/system_report.txt  
<%= envar_flag = true %>
<%= erb_flag = true %>

System Status Report
===================
Generated: <%= Time.now.strftime('%Y-%m-%d %H:%M:%S') %>

Environment: $RAILS_ENV
Version: $APP_VERSION
Server: $HOSTNAME
User: $USER

Database Status: [DB_STATUS]
Cache Status: [CACHE_STATUS]
Queue Status: [QUEUE_STATUS]

<% if ENV['RAILS_ENV'] == 'production' %>
🔴 PRODUCTION ENVIRONMENT - Handle with care!
<% else %>
🟡 Development Environment
<% end %>

Memory Usage: <%= `ps -o pid,ppid,pmem,comm -p #{Process.pid}`.split("\n").last %>
```

### Configuration-Driven Prompts

```ruby
# config/prompt_config.yml
development:
  api_endpoints:
    user_service: "http://localhost:3001"
    payment_service: "http://localhost:3002"
  debug_mode: true
  
production:
  api_endpoints:
    user_service: "https://api.example.com/users"
    payment_service: "https://api.example.com/payments"  
  debug_mode: false

# prompts/api_integration.txt
<%= erb_flag = true %>
<%= envar_flag = true %>

<% config = YAML.load_file("config/prompt_config.yml")[ENV['RAILS_ENV']] %>

API Integration Guide
====================

User Service: <%= config['api_endpoints']['user_service'] %>
Payment Service: <%= config['api_endpoints']['payment_service'] %>

<% if config['debug_mode'] %>
Debug Mode: Enabled
- Verbose logging active
- Request/response tracing enabled  
<% end %>

Request Headers:
- Authorization: Bearer $API_TOKEN
- Content-Type: application/json
- X-Client-Version: $APP_VERSION
```

## Error Handling and Fallbacks

### Graceful Degradation System

```ruby
class RobustPromptRenderer
  def initialize(primary_prompt_id, fallback_prompt_id = nil)
    @primary_prompt_id = primary_prompt_id
    @fallback_prompt_id = fallback_prompt_id
  end
  
  def render(parameters = {})
    render_primary(parameters)
  rescue PromptManager::PromptNotFoundError
    render_fallback(parameters)
  rescue PromptManager::MissingParametersError => e
    render_with_defaults(parameters, e.missing_parameters)
  rescue => e
    render_error_response(e, parameters)
  end
  
  private
  
  def render_primary(parameters)
    prompt = PromptManager::Prompt.new(id: @primary_prompt_id)
    prompt.render(parameters)
  end
  
  def render_fallback(parameters)
    return "Service temporarily unavailable" unless @fallback_prompt_id
    
    prompt = PromptManager::Prompt.new(id: @fallback_prompt_id)
    prompt.render(parameters)
  rescue
    "Default response: Thank you for your request."
  end
  
  def render_with_defaults(parameters, missing_params)
    # Provide default values for missing parameters
    defaults = {
      'customer_name' => 'Valued Customer',
      'order_id' => 'N/A',
      'date' => Date.today.to_s
    }
    
    filled_params = parameters.dup
    missing_params.each do |param|
      filled_params[param.downcase.to_sym] = defaults[param] || "[#{param}]"
    end
    
    render_primary(filled_params)
  end
  
  def render_error_response(error, parameters)
    Rails.logger.error "Prompt rendering failed: #{error.message}"
    Rails.logger.error "Parameters: #{parameters.inspect}"
    
    "We're sorry, but we encountered an error processing your request. Please try again later."
  end
end

# Usage
renderer = RobustPromptRenderer.new('customer_welcome', 'generic_welcome')
message = renderer.render(customer_name: 'John Doe')
```

## Performance Optimization

### Prompt Caching Strategy

```ruby
class CachedPromptRenderer
  include ActiveSupport::Benchmarkable
  
  def initialize(cache_store = Rails.cache)
    @cache = cache_store
  end
  
  def render(prompt_id, parameters = {}, cache_options = {})
    cache_key = generate_cache_key(prompt_id, parameters)
    
    @cache.fetch(cache_key, cache_options) do
      benchmark "Rendering prompt #{prompt_id}" do
        prompt = PromptManager::Prompt.new(id: prompt_id)
        prompt.render(parameters)
      end
    end
  end
  
  def warm_cache(prompt_configs)
    prompt_configs.each do |config|
      render(config[:prompt_id], config[:parameters], expires_in: 1.hour)
    end
  end
  
  def invalidate_cache(prompt_id, parameters = nil)
    if parameters
      cache_key = generate_cache_key(prompt_id, parameters)
      @cache.delete(cache_key)
    else
      # Invalidate all cached versions of this prompt
      pattern = "prompt:#{prompt_id}:*"
      @cache.delete_matched(pattern)
    end
  end
  
  private
  
  def generate_cache_key(prompt_id, parameters)
    param_hash = Digest::MD5.hexdigest(parameters.to_json)
    "prompt:#{prompt_id}:#{param_hash}"
  end
end

# Usage
cache_renderer = CachedPromptRenderer.new
result = cache_renderer.render('welcome_email', { name: 'Alice' }, expires_in: 30.minutes)

# Warm frequently used prompts
cache_renderer.warm_cache([
  { prompt_id: 'welcome_email', parameters: { name: 'Default User' } },
  { prompt_id: 'order_confirmation', parameters: { status: 'pending' } }
])
```

## Integration Patterns

### Background Job Processing

```ruby
class PromptProcessingJob < ApplicationJob
  queue_as :default
  
  def perform(prompt_id, parameters, notification_settings = {})
    prompt = PromptManager::Prompt.new(id: prompt_id)
    content = prompt.render(parameters)
    
    case notification_settings[:delivery_method]
    when 'email'
      send_email_notification(content, notification_settings)
    when 'sms'
      send_sms_notification(content, notification_settings)
    when 'push'
      send_push_notification(content, notification_settings)
    when 'webhook'
      send_webhook_notification(content, notification_settings)
    end
    
    log_notification_sent(prompt_id, parameters, notification_settings)
    
  rescue => e
    handle_processing_error(e, prompt_id, parameters, notification_settings)
  end
  
  private
  
  def send_email_notification(content, settings)
    NotificationMailer.custom_message(
      to: settings[:email],
      subject: settings[:subject],
      content: content
    ).deliver_now
  end
  
  def send_webhook_notification(content, settings)
    HTTParty.post(settings[:webhook_url], {
      body: {
        content: content,
        timestamp: Time.current,
        metadata: settings[:metadata]
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{settings[:api_token]}"
      }
    })
  end
  
  def handle_processing_error(error, prompt_id, parameters, settings)
    Rails.logger.error "Prompt processing failed: #{error.message}"
    
    # Send error notification
    AdminMailer.prompt_processing_error(
      error: error,
      prompt_id: prompt_id,
      parameters: parameters,
      settings: settings
    ).deliver_now
    
    # Retry with fallback prompt if available
    if settings[:fallback_prompt_id]
      PromptProcessingJob.perform_later(
        settings[:fallback_prompt_id],
        parameters,
        settings.merge(retry_count: (settings[:retry_count] || 0) + 1)
      )
    end
  end
end

# Usage
PromptProcessingJob.perform_later(
  'order_shipped',
  {
    customer_name: 'John Doe',
    order_id: 'ORD-123',
    tracking_number: 'TRK-456',
    estimated_delivery: Date.tomorrow
  },
  {
    delivery_method: 'email',
    email: 'customer@example.com',
    subject: 'Your Order Has Shipped!',
    fallback_prompt_id: 'generic_shipping_notification'
  }
)
```

These advanced examples demonstrate the full power and flexibility of PromptManager for complex, real-world applications. They show how to handle nested data structures, implement sophisticated error handling, optimize performance, and integrate with background processing systems.