# Custom Keywords

PromptManager allows you to define custom keywords and parameter patterns beyond the standard `[PARAMETER_NAME]` syntax.

## Overview

Custom keywords enable you to create domain-specific parameter patterns, validation rules, and transformation logic for your prompts.

## Defining Custom Keywords

### Basic Custom Keywords

```ruby
PromptManager.configure do |config|
  config.custom_keywords = {
    'EMAIL' => {
      pattern: /\{EMAIL:([^}]+)\}/,
      validator: ->(value) { value.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) },
      transformer: ->(value) { value.downcase }
    },
    
    'PHONE' => {
      pattern: /\{PHONE:([^}]+)\}/,
      validator: ->(value) { value.match?(/\A\+?[\d\-\(\)\s]+\z/) },
      transformer: ->(value) { value.gsub(/[^\d+]/, '') }
    },
    
    'CURRENCY' => {
      pattern: /\{CURRENCY:([^}]+):([A-Z]{3})\}/,
      transformer: ->(amount, currency) { 
        formatted = sprintf('%.2f', amount.to_f)
        case currency
        when 'USD' then "$#{formatted}"
        when 'EUR' then "€#{formatted}"
        else "#{formatted} #{currency}"
        end
      }
    }
  }
end
```

### Usage in Prompts

```text
# email_template.txt
Dear Customer,

Your account {EMAIL:customer_email} has been updated.
Please contact us at {PHONE:support_phone} if you have questions.
Your order total is {CURRENCY:order_amount:USD}.

Best regards,
Support Team
```

```ruby
prompt = PromptManager::Prompt.new(id: 'email_template')
result = prompt.render(
  customer_email: 'JOHN.DOE@EXAMPLE.COM',
  support_phone: '1-800-555-0123',
  order_amount: 123.45
)

# Result:
# Dear Customer,
# Your account john.doe@example.com has been updated.
# Please contact us at +18005550123 if you have questions.
# Your order total is $123.45.
```

## Advanced Custom Keywords

### Conditional Keywords

```ruby
config.custom_keywords['IF_PREMIUM'] = {
  pattern: /\{IF_PREMIUM:([^}]+)\}/,
  processor: ->(content, context) {
    user_tier = context.dig(:parameters, :user_tier)
    user_tier == 'premium' ? content : ''
  }
}
```

```text
# Usage in prompt:
{IF_PREMIUM:🌟 Thank you for being a Premium member!}
```

### Loop Keywords

```ruby
config.custom_keywords['FOREACH'] = {
  pattern: /\{FOREACH:([^:]+):([^}]+)\}/,
  processor: ->(array_name, template, context) {
    array_data = context.dig(:parameters, array_name.to_sym) || []
    
    array_data.map.with_index do |item, index|
      item_template = template.gsub(/\{ITEM\.(\w+)\}/) { item[Regexp.last_match(1).to_sym] }
      item_template.gsub(/\{INDEX\}/, index.to_s)
    end.join("\n")
  }
}
```

```text
# Usage in prompt:
Your order items:
{FOREACH:order_items:- {ITEM.name}: ${ITEM.price}}
```

### Date/Time Keywords

```ruby
config.custom_keywords['DATE'] = {
  pattern: /\{DATE:([^:}]+)(?::([^}]+))?\}/,
  processor: ->(format, offset, context) {
    base_date = Time.current
    
    if offset
      case offset
      when /\+(\d+)d/ then base_date += Regexp.last_match(1).to_i.days
      when /-(\d+)d/ then base_date -= Regexp.last_match(1).to_i.days
      when /\+(\d+)w/ then base_date += Regexp.last_match(1).to_i.weeks
      end
    end
    
    base_date.strftime(format)
  }
}
```

```text
# Usage in prompt:
Today: {DATE:%B %d, %Y}
Next week: {DATE:%B %d, %Y:+7d}
Last month: {DATE:%B %Y:-1m}
```

## Validation and Error Handling

### Parameter Validation

```ruby
config.custom_keywords['VALIDATED_EMAIL'] = {
  pattern: /\{EMAIL:([^}]+)\}/,
  validator: ->(email) {
    return false unless email.is_a?(String)
    return false unless email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
    
    # Additional validation
    domain = email.split('@').last
    !['tempmail.com', 'throwaway.email'].include?(domain)
  },
  error_message: 'Please provide a valid email address from an allowed domain'
}
```

### Custom Error Handling

```ruby
class CustomKeywordProcessor
  def self.process_keyword(keyword, args, context)
    case keyword
    when 'SECURE_DATA'
      return '[REDACTED]' if context[:redact_sensitive_data]
      args.first
      
    when 'API_CALL'
      begin
        api_result = make_api_call(args.first)
        api_result['data']
      rescue => e
        Rails.logger.error "API call failed: #{e.message}"
        '[API_ERROR]'
      end
      
    else
      raise PromptManager::UnknownKeywordError.new("Unknown keyword: #{keyword}")
    end
  end
end
```

## Dynamic Keywords

### Runtime Registration

```ruby
class DynamicKeywordManager
  def self.register_for_user(user)
    PromptManager.configure do |config|
      config.custom_keywords ||= {}
      
      # User-specific keywords
      config.custom_keywords["USER_#{user.id}_NAME"] = {
        pattern: /\{USER_NAME\}/,
        processor: ->(*args, context) { user.full_name }
      }
      
      # Role-based keywords
      if user.admin?
        config.custom_keywords['ADMIN_PANEL'] = {
          pattern: /\{ADMIN_PANEL:([^}]+)\}/,
          processor: ->(content, context) { content }
        }
      end
    end
  end
end

# Usage
DynamicKeywordManager.register_for_user(current_user)
```

### Database-Driven Keywords

```ruby
class DatabaseKeywordLoader
  def self.load_keywords
    CustomKeyword.active.each do |keyword_record|
      PromptManager.configure do |config|
        config.custom_keywords[keyword_record.name] = {
          pattern: Regexp.new(keyword_record.pattern),
          processor: eval(keyword_record.processor_code),
          description: keyword_record.description
        }
      end
    end
  end
end

# Load keywords on application startup
DatabaseKeywordLoader.load_keywords
```

## Integration with ERB

### ERB-Enhanced Keywords

```ruby
config.custom_keywords['ERB_EVAL'] = {
  pattern: /\{ERB:([^}]+)\}/,
  processor: ->(erb_code, context) {
    template = ERB.new(erb_code)
    template.result(binding)
  }
}
```

```text
# Usage in prompt:
Current time: {ERB:<%= Time.current.strftime('%H:%M') %>}
Random number: {ERB:<%= rand(100) %>}
```

### Template Inheritance

```ruby
config.custom_keywords['PARENT'] = {
  pattern: /\{PARENT:([^}]+)\}/,
  processor: ->(parent_template, context) {
    parent_prompt = PromptManager::Prompt.new(id: parent_template)
    parent_prompt.render(context[:parameters])
  }
}
```

## Performance Optimization

### Keyword Caching

```ruby
class CachedKeywordProcessor
  @cache = {}
  
  def self.process_with_cache(keyword, args, context, cache_ttl: 300)
    cache_key = "#{keyword}:#{args.join(':')}:#{context.hash}"
    
    cached_result = @cache[cache_key]
    if cached_result && (Time.current - cached_result[:timestamp]) < cache_ttl
      return cached_result[:value]
    end
    
    result = process_keyword(keyword, args, context)
    @cache[cache_key] = {
      value: result,
      timestamp: Time.current
    }
    
    result
  end
end
```

### Lazy Evaluation

```ruby
config.custom_keywords['LAZY_LOAD'] = {
  pattern: /\{LAZY:([^}]+)\}/,
  processor: ->(data_source, context) {
    # Only load data when actually needed
    -> { expensive_data_load(data_source) }
  }
}
```

## Testing Custom Keywords

### RSpec Examples

```ruby
describe 'Custom Keywords' do
  before do
    PromptManager.configure do |config|
      config.custom_keywords = {
        'TEST_UPPER' => {
          pattern: /\{UPPER:([^}]+)\}/,
          transformer: ->(value) { value.upcase }
        }
      }
    end
  end
  
  it 'processes custom keyword' do
    prompt = PromptManager::Prompt.new(id: 'test')
    allow(prompt.storage).to receive(:read).and_return('Hello {UPPER:world}')
    
    result = prompt.render
    expect(result).to eq 'Hello WORLD'
  end
  
  it 'validates custom keyword input' do
    PromptManager.configure do |config|
      config.custom_keywords['VALIDATED'] = {
        pattern: /\{VALIDATED:([^}]+)\}/,
        validator: ->(value) { value.length > 3 },
        error_message: 'Value must be longer than 3 characters'
      }
    end
    
    prompt = PromptManager::Prompt.new(id: 'test')
    allow(prompt.storage).to receive(:read).and_return('Hello {VALIDATED:ab}')
    
    expect {
      prompt.render
    }.to raise_error(PromptManager::ValidationError, /Value must be longer than 3 characters/)
  end
end
```

## Real-World Examples

### E-commerce Keywords

```ruby
PromptManager.configure do |config|
  config.custom_keywords.merge!({
    'PRICE' => {
      pattern: /\{PRICE:([^:}]+)(?::([A-Z]{3}))?\}/,
      processor: ->(amount, currency, context) {
        currency ||= 'USD'
        user_country = context.dig(:parameters, :user_country)
        
        # Adjust currency based on user location
        case user_country
        when 'GB' then currency = 'GBP'
        when 'DE', 'FR', 'IT' then currency = 'EUR'
        end
        
        CurrencyFormatter.format(amount.to_f, currency)
      }
    },
    
    'INVENTORY_STATUS' => {
      pattern: /\{STOCK:([^}]+)\}/,
      processor: ->(product_id, context) {
        stock_level = InventoryService.check_stock(product_id)
        
        case stock_level
        when 0 then '❌ Out of Stock'
        when 1..5 then '⚠️ Low Stock'
        else '✅ In Stock'
        end
      }
    }
  })
end
```

### Localization Keywords

```ruby
config.custom_keywords['TRANSLATE'] = {
  pattern: /\{T:([^:}]+)(?::([a-z]{2}))?\}/,
  processor: ->(key, locale, context) {
    locale ||= context.dig(:parameters, :locale) || 'en'
    I18n.with_locale(locale) { I18n.t(key) }
  }
}

config.custom_keywords['PLURALIZE'] = {
  pattern: /\{PLURAL:([^:]+):([^:]+):([^}]+)\}/,
  processor: ->(count, singular, plural, context) {
    count_val = context.dig(:parameters, count.to_sym) || 0
    count_val.to_i == 1 ? singular : plural
  }
}
```

## Best Practices

1. **Descriptive Names**: Use clear, descriptive names for custom keywords
2. **Validation**: Always validate input parameters
3. **Error Handling**: Provide meaningful error messages
4. **Documentation**: Document keyword syntax and behavior
5. **Performance**: Cache expensive operations
6. **Security**: Sanitize user input in keyword processors
7. **Testing**: Write comprehensive tests for custom keywords
8. **Consistency**: Follow consistent naming conventions across keywords