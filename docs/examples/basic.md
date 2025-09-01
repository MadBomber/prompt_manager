# Basic Examples

This section provides practical, ready-to-use examples that demonstrate PromptManager's core functionality. Each example includes complete code and explanations.

## Setup

All examples assume this basic setup:

```ruby
require 'prompt_manager'

# Configure FileSystem adapter
PromptManager::Prompt.storage_adapter = 
  PromptManager::Storage::FileSystemAdapter.config do |config|
    config.prompts_dir = File.expand_path('~/.prompts')
  end.new
```

## Example 1: Simple Greeting

The classic "Hello World" example for prompts.

### Prompt File

```text title="~/.prompts/greeting.txt"
# Simple greeting prompt
# Keywords: NAME

Hello [NAME]! Welcome to PromptManager.

How can I help you today?
```

### Parameters File

```json title="~/.prompts/greeting.json"
{
  "[NAME]": ["World", "Alice", "Bob"]
}
```

### Ruby Code

```ruby title="greeting_example.rb"
#!/usr/bin/env ruby
require 'prompt_manager'

# Configure storage
PromptManager::Prompt.storage_adapter = 
  PromptManager::Storage::FileSystemAdapter.config do |config|
    config.prompts_dir = File.expand_path('~/.prompts')
  end.new

# Load and use the prompt
prompt = PromptManager::Prompt.new(id: 'greeting')
prompt.parameters['[NAME]'] = 'Alice'

puts prompt.to_s
# Output: Hello Alice! Welcome to PromptManager.\n\nHow can I help you today?
```

**Key Learning Points:**
- Basic prompt loading with `new(id: 'greeting')`  
- Parameter setting with direct assignment
- Text generation with `to_s`

## Example 2: Email Template

A more realistic example showing email template management.

### Prompt File

```text title="~/.prompts/welcome_email.txt"
# Welcome email template
# Keywords: USER_NAME, COMPANY_NAME, LOGIN_URL, SUPPORT_EMAIL

Subject: Welcome to [COMPANY_NAME]!

Dear [USER_NAME],

Welcome to [COMPANY_NAME]! We're excited to have you join our community.

To get started:
1. Log in to your account: [LOGIN_URL]
2. Complete your profile setup
3. Explore our features

If you need any help, don't hesitate to contact us at [SUPPORT_EMAIL].

Best regards,
The [COMPANY_NAME] Team
```

### Ruby Code

```ruby title="email_example.rb"
require 'prompt_manager'

class WelcomeEmailGenerator
  def initialize
    @prompt = PromptManager::Prompt.new(id: 'welcome_email')
  end
  
  def generate_for_user(user_data)
    @prompt.parameters = {
      '[USER_NAME]' => user_data[:name],
      '[COMPANY_NAME]' => 'Acme Corp',
      '[LOGIN_URL]' => 'https://app.acme.com/login',
      '[SUPPORT_EMAIL]' => 'support@acme.com'
    }
    
    @prompt.to_s
  end
end

# Usage
generator = WelcomeEmailGenerator.new
user = { name: 'Alice Johnson', email: 'alice@example.com' }

email_content = generator.generate_for_user(user)
puts email_content

# Save parameters for future use
generator.instance_variable_get(:@prompt).save
```

**Key Learning Points:**
- Organizing prompt logic in classes
- Batch parameter assignment with hash
- Saving parameter changes back to storage

## Example 3: Dynamic Content with ERB

Using ERB for conditional content and dynamic generation.

### Prompt File

```text title="~/.prompts/order_confirmation.txt"
# Order confirmation with dynamic content
# Keywords: CUSTOMER_NAME, ORDER_NUMBER, ITEM_COUNT, TOTAL_AMOUNT, IS_PREMIUM

Dear [CUSTOMER_NAME],

Thank you for your order #[ORDER_NUMBER]!

<% item_count = '[ITEM_COUNT]'.to_i %>
Your order contains <%= item_count %> item<%= 's' if item_count != 1 %>.

<% if '[IS_PREMIUM]' == 'true' %>
🌟 As a premium member, you'll receive:
- Free express shipping
- Priority customer support  
- Extended warranty on all items
<% else %>
Standard shipping will be applied to your order.
<% end %>

Order Total: $[TOTAL_AMOUNT]

<% if '[TOTAL_AMOUNT]'.to_f > 100 %>
🎉 Congratulations! You qualify for free shipping!
<% end %>

Best regards,
Customer Service Team
```

### Ruby Code

```ruby title="order_confirmation_example.rb"
require 'prompt_manager'

class OrderConfirmation
  def initialize
    # Enable ERB processing
    @prompt = PromptManager::Prompt.new(
      id: 'order_confirmation',
      erb_flag: true
    )
  end
  
  def generate(order)
    @prompt.parameters = {
      '[CUSTOMER_NAME]' => order[:customer_name],
      '[ORDER_NUMBER]' => order[:order_number],
      '[ITEM_COUNT]' => order[:items].count.to_s,
      '[TOTAL_AMOUNT]' => sprintf('%.2f', order[:total]),
      '[IS_PREMIUM]' => order[:premium_member].to_s
    }
    
    @prompt.to_s
  end
end

# Usage with different order types
confirmation = OrderConfirmation.new

# Regular customer order
regular_order = {
  customer_name: 'John Smith',
  order_number: 'ORD-12345',
  items: ['Widget A', 'Widget B'],
  total: 85.50,
  premium_member: false
}

puts "=== Regular Order ==="
puts confirmation.generate(regular_order)

# Premium customer order
premium_order = {
  customer_name: 'Jane Doe',
  order_number: 'ORD-12346', 
  items: ['Premium Widget', 'Deluxe Kit', 'Accessories'],
  total: 150.00,
  premium_member: true
}

puts "\n=== Premium Order ==="
puts confirmation.generate(premium_order)
```

**Key Learning Points:**
- Enabling ERB with `erb_flag: true`
- Conditional content using ERB syntax
- Dynamic content generation based on parameter values

## Example 4: Directive Processing

Using directives to include shared content and build modular prompts.

### Shared Header File

```text title="~/.prompts/common/header.txt"
=====================================
    ACME CORPORATION
    Customer Service Division
=====================================

Date: <%= Date.today.strftime('%B %d, %Y') %>
```

### Shared Footer File  

```text title="~/.prompts/common/footer.txt"
=====================================

For immediate assistance:
📞 Call: 1-800-ACME-HELP
📧 Email: support@acme.com  
🌐 Web: https://help.acme.com

Office Hours: Monday-Friday, 9 AM - 6 PM EST
```

### Main Prompt File

```text title="~/.prompts/customer_response.txt"
# Customer service response template
# Keywords: CUSTOMER_NAME, ISSUE_TYPE, RESOLUTION_TIME, AGENT_NAME

//include common/header.txt

Dear [CUSTOMER_NAME],

Thank you for contacting us regarding your [ISSUE_TYPE] issue.

We understand your concern and want to resolve this as quickly as possible. 
Based on our initial review, we expect to have this resolved within [RESOLUTION_TIME].

I'll personally be handling your case and will keep you updated on our progress.

Best regards,
[AGENT_NAME]
Customer Service Representative

//include common/footer.txt
```

### Ruby Code

```ruby title="customer_response_example.rb"
require 'prompt_manager'

class CustomerServiceResponse
  def initialize
    @prompt = PromptManager::Prompt.new(
      id: 'customer_response',
      erb_flag: true  # Enable ERB for header date processing
    )
  end
  
  def generate_response(case_data)
    @prompt.parameters = {
      '[CUSTOMER_NAME]' => case_data[:customer_name],
      '[ISSUE_TYPE]' => case_data[:issue_type],
      '[RESOLUTION_TIME]' => case_data[:expected_resolution],
      '[AGENT_NAME]' => case_data[:agent_name]
    }
    
    @prompt.to_s
  end
end

# Usage
response_generator = CustomerServiceResponse.new

customer_case = {
  customer_name: 'Sarah Wilson',
  issue_type: 'billing discrepancy',
  expected_resolution: '2-3 business days',
  agent_name: 'Mike Johnson'
}

puts response_generator.generate_response(customer_case)
```

**Key Learning Points:**
- Using `//include` directives for shared content
- Combining ERB and directive processing
- Building modular, reusable prompt components

## Example 5: Parameter History and Management

Leveraging parameter history for better user experience.

### Ruby Code

```ruby title="parameter_history_example.rb"
require 'prompt_manager'

class PromptWithHistory
  def initialize(prompt_id)
    @prompt = PromptManager::Prompt.new(id: prompt_id)
  end
  
  def set_parameter(key, value)
    # Get current history
    current_history = @prompt.parameters[key] || []
    
    # Add new value if it's different from the last one
    unless current_history.last == value
      current_history << value
      # Keep only last 10 values
      current_history = current_history.last(10)
    end
    
    @prompt.parameters[key] = current_history
    @prompt.save
  end
  
  def get_parameter_history(key)
    @prompt.parameters[key] || []
  end
  
  def get_current_parameter(key)
    history = get_parameter_history(key)
    history.empty? ? nil : history.last
  end
  
  def get_parameter_suggestions(key, limit = 5)
    history = get_parameter_history(key)
    history.reverse.take(limit)
  end
  
  def generate
    @prompt.to_s
  end
end

# Usage example
class InteractivePromptBuilder
  def initialize
    @prompt_manager = PromptWithHistory.new('greeting')
  end
  
  def interactive_session
    puts "=== Interactive Prompt Builder ==="
    puts "Available keywords: #{@prompt_manager.instance_variable_get(:@prompt).keywords.join(', ')}"
    
    @prompt_manager.instance_variable_get(:@prompt).keywords.each do |keyword|
      # Show previous values
      suggestions = @prompt_manager.get_parameter_suggestions(keyword)
      
      if suggestions.any?
        puts "\nPrevious values for #{keyword}:"
        suggestions.each_with_index do |value, index|
          puts "  #{index + 1}. #{value}"
        end
        puts "  #{suggestions.length + 1}. Enter new value"
        
        print "Choose option or enter new value: "
        input = gets.chomp
        
        if input.to_i.between?(1, suggestions.length)
          selected_value = suggestions[input.to_i - 1]
          @prompt_manager.set_parameter(keyword, selected_value)
          puts "Selected: #{selected_value}"
        else
          @prompt_manager.set_parameter(keyword, input)
          puts "New value saved: #{input}"
        end
      else
        print "Enter value for #{keyword}: "
        value = gets.chomp
        @prompt_manager.set_parameter(keyword, value)
      end
    end
    
    puts "\n=== Generated Prompt ==="
    puts @prompt_manager.generate
  end
end

# Run interactive session
# InteractivePromptBuilder.new.interactive_session
```

**Key Learning Points:**
- Working with parameter history arrays  
- Building user-friendly parameter selection
- Maintaining parameter history across sessions

## Example 6: Error Handling

Robust error handling for production use.

### Ruby Code

```ruby title="error_handling_example.rb"
require 'prompt_manager'

class RobustPromptProcessor
  def initialize(prompt_id)
    @prompt_id = prompt_id
    @prompt = nil
  end
  
  def process_with_fallback(parameters, fallback_text = nil)
    begin
      # Attempt to load prompt
      @prompt = PromptManager::Prompt.new(id: @prompt_id)
      
      # Validate required parameters
      validate_parameters(parameters)
      
      # Set parameters
      @prompt.parameters = parameters
      
      # Generate text
      result = @prompt.to_s
      
      # Check for unreplaced keywords
      check_unreplaced_keywords(result)
      
      { success: true, text: result }
      
    rescue PromptManager::StorageError => e
      handle_storage_error(e, fallback_text)
    rescue PromptManager::ParameterError => e
      handle_parameter_error(e)  
    rescue => e
      handle_unexpected_error(e, fallback_text)
    ensure
      # Always try to save any parameter changes
      save_parameters_safely if @prompt
    end
  end
  
  private
  
  def validate_parameters(parameters)
    return unless @prompt
    
    required_keywords = @prompt.keywords
    provided_keywords = parameters.keys
    missing = required_keywords - provided_keywords
    
    unless missing.empty?
      raise PromptManager::ParameterError, "Missing required parameters: #{missing.join(', ')}"
    end
  end
  
  def check_unreplaced_keywords(text)
    # Look for unreplaced keywords (basic pattern)
    unreplaced = text.scan(/\[([A-Z_\s]+)\]/).flatten
    
    if unreplaced.any?
      puts "⚠️  Warning: Found unreplaced keywords: #{unreplaced.join(', ')}"
    end
  end
  
  def handle_storage_error(error, fallback_text)
    puts "❌ Storage Error: #{error.message}"
    
    if fallback_text
      puts "📄 Using fallback text"
      { success: false, text: fallback_text, error: :storage_error }
    else
      { success: false, error: :storage_error, message: error.message }
    end
  end
  
  def handle_parameter_error(error)
    puts "❌ Parameter Error: #{error.message}"
    { success: false, error: :parameter_error, message: error.message }
  end
  
  def handle_unexpected_error(error, fallback_text)
    puts "❌ Unexpected Error: #{error.class} - #{error.message}"
    puts error.backtrace.first(3) if ENV['DEBUG']
    
    if fallback_text
      { success: false, text: fallback_text, error: :unexpected_error }
    else
      { success: false, error: :unexpected_error, message: error.message }
    end
  end
  
  def save_parameters_safely
    @prompt.save
  rescue => e
    puts "⚠️  Warning: Could not save parameters: #{e.message}"
  end
end

# Usage examples
processor = RobustPromptProcessor.new('welcome_email')

# Successful processing
result = processor.process_with_fallback({
  '[USER_NAME]' => 'Alice',
  '[COMPANY_NAME]' => 'Acme Corp'
})

puts "Success: #{result[:success]}"
puts result[:text] if result[:success]

# Error handling with fallback
fallback = "Welcome! Thank you for joining us."

result = processor.process_with_fallback(
  { '[USER_NAME]' => 'Bob' },  # Missing required parameter
  fallback
)

puts "Success: #{result[:success]}"
puts "Error: #{result[:error]}" unless result[:success]
puts "Text: #{result[:text]}" if result[:text]
```

**Key Learning Points:**
- Comprehensive error handling for all error types
- Graceful fallback strategies  
- Parameter validation and safety checks
- Production-ready error reporting

## Example 7: Batch Processing

Processing multiple prompts efficiently.

### Ruby Code

```ruby title="batch_processing_example.rb"  
require 'prompt_manager'

class BatchPromptProcessor
  def initialize
    @results = []
    @errors = []
  end
  
  def process_batch(prompt_configs)
    prompt_configs.each_with_index do |config, index|
      begin
        result = process_single_prompt(config)
        @results << { index: index, config: config, result: result }
        puts "✅ Processed #{config[:id]} successfully"
      rescue => e
        error = { index: index, config: config, error: e }
        @errors << error
        puts "❌ Failed to process #{config[:id]}: #{e.message}"
      end
    end
    
    summary
  end
  
  def process_single_prompt(config)
    prompt = PromptManager::Prompt.new(
      id: config[:id],
      erb_flag: config[:erb_flag] || false
    )
    
    prompt.parameters = config[:parameters]
    prompt.to_s
  end
  
  def summary
    {
      total: @results.length + @errors.length,
      successful: @results.length,
      failed: @errors.length,
      results: @results,
      errors: @errors
    }
  end
  
  def successful_results
    @results.map { |r| r[:result] }
  end
  
  def failed_configs
    @errors.map { |e| e[:config] }
  end
end

# Usage
batch_configs = [
  {
    id: 'greeting',
    parameters: { '[NAME]' => 'Alice' }
  },
  {
    id: 'welcome_email', 
    parameters: {
      '[USER_NAME]' => 'Bob',
      '[COMPANY_NAME]' => 'Acme Corp',
      '[LOGIN_URL]' => 'https://app.acme.com',
      '[SUPPORT_EMAIL]' => 'support@acme.com'
    }
  },
  {
    id: 'order_confirmation',
    erb_flag: true,
    parameters: {
      '[CUSTOMER_NAME]' => 'Charlie',
      '[ORDER_NUMBER]' => 'ORD-789',
      '[ITEM_COUNT]' => '3',
      '[TOTAL_AMOUNT]' => '199.99',
      '[IS_PREMIUM]' => 'true'
    }
  }
]

processor = BatchPromptProcessor.new
summary = processor.process_batch(batch_configs)

puts "\n=== Batch Processing Summary ==="
puts "Total: #{summary[:total]}"
puts "Successful: #{summary[:successful]}"  
puts "Failed: #{summary[:failed]}"

if summary[:failed] > 0
  puts "\nFailed prompts:"
  processor.failed_configs.each do |config|
    puts "  - #{config[:id]}"
  end
end
```

**Key Learning Points:**
- Batch processing patterns
- Error collection and reporting
- Processing summaries and statistics
- Handling mixed success/failure scenarios

## Running the Examples

1. **Create the prompts directory:**
   ```bash
   mkdir -p ~/.prompts/common
   ```

2. **Create the prompt files** shown in each example

3. **Run any example:**
   ```bash
   ruby greeting_example.rb
   ruby email_example.rb  
   # etc.
   ```

## Next Steps

- **Advanced Examples**: See [Advanced Examples](advanced.md) for complex scenarios
- **Real World Cases**: Check [Real World Use Cases](real-world.md) for production examples  
- **Core Features**: Learn more about [Parameterized Prompts](../core-features/parameterized-prompts.md)