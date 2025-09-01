# Parameterized Prompts

Parameterized prompts are the heart of PromptManager. They allow you to create reusable template prompts with placeholders (keywords) that can be filled with different values.

## Basic Concepts

### What are Keywords?

Keywords are placeholders in your prompt text that get replaced with actual values. By default, they follow the pattern `[UPPERCASE_TEXT]`:

```text
Hello [NAME]! Today is [DATE] and you have [COUNT] messages.
```

### Parameter Substitution

When you provide parameter values, PromptManager replaces keywords with their corresponding values:

```ruby
prompt.parameters = {
  "[NAME]" => "Alice",
  "[DATE]" => "2024-01-15", 
  "[COUNT]" => "3"
}

puts prompt.to_s
# Output: Hello Alice! Today is 2024-01-15 and you have 3 messages.
```

## Keyword Formats

### Default Format

The default keyword pattern is `[UPPERCASE_WITH_UNDERSCORES_AND_SPACES]`:

```text
# Valid keywords
[NAME]
[USER_NAME] 
[FIRST_NAME]
[ORDER NUMBER]  # Spaces allowed
[API_KEY]
```

### Custom Keyword Patterns

You can customize the keyword pattern to match your preferences:

=== "Mustache Style"

    ```ruby
    PromptManager::Prompt.parameter_regex = /(\{\{[a-z_]+\}\})/
    
    # Now use: {{name}}, {{user_name}}, {{api_key}}
    prompt_text = "Hello {{name}}, your key is {{api_key}}"
    ```

=== "Colon Style"

    ```ruby
    PromptManager::Prompt.parameter_regex = /(:[a-z_]+)/
    
    # Now use: :name, :user_name, :api_key  
    prompt_text = "Hello :name, your key is :api_key"
    ```

=== "Dollar Style"

    ```ruby
    PromptManager::Prompt.parameter_regex = /(\$[A-Z_]+)/
    
    # Now use: $NAME, $USER_NAME, $API_KEY
    prompt_text = "Hello $NAME, your key is $API_KEY"
    ```

!!! warning "Regex Requirements"
    Your custom regex must include capturing parentheses `()` to extract the keyword. The capture group should include the delimiter characters.

## Working with Parameters

### Setting Parameters

There are several ways to set parameter values:

=== "Direct Assignment"

    ```ruby
    prompt.parameters = {
      "[NAME]" => "Alice",
      "[EMAIL]" => "alice@example.com"
    }
    ```

=== "Individual Assignment"

    ```ruby
    prompt.parameters["[NAME]"] = "Bob"
    prompt.parameters["[EMAIL]"] = "bob@example.com"
    ```

=== "Batch Update"

    ```ruby
    new_params = {
      "[NAME]" => "Charlie",
      "[ROLE]" => "Administrator"
    }
    prompt.parameters.merge!(new_params)
    ```

### Parameter History (v0.3.0+)

Since version 0.3.0, parameters maintain a history of values as arrays:

```ruby
# Setting a single value
prompt.parameters["[NAME]"] = "Alice"

# Internally stored as: ["Alice"]
# The last value is always the most recent

# Adding more values
prompt.parameters["[NAME]"] = ["Alice", "Bob", "Charlie"]

# Get the current value
current_name = prompt.parameters["[NAME]"].last  # "Charlie"

# Get the full history
all_names = prompt.parameters["[NAME]"]  # ["Alice", "Bob", "Charlie"]
```

This history is useful for:

- Building dropdown lists in UIs
- Providing auto-completion
- Tracking parameter usage over time
- Implementing "recent values" functionality

### Getting Available Keywords

Discover what keywords are available in a prompt:

```ruby
prompt = PromptManager::Prompt.new(id: 'email_template')
keywords = prompt.keywords
puts "Required parameters: #{keywords.join(', ')}"
# Output: Required parameters: [TO_NAME], [FROM_NAME], [SUBJECT], [BODY]
```

### Checking for Missing Parameters

```ruby
def check_missing_parameters(prompt)
  required = prompt.keywords.to_set
  provided = prompt.parameters.keys.to_set
  missing = required - provided
  
  unless missing.empty?
    puts "⚠️  Missing parameters: #{missing.to_a.join(', ')}"
    return false
  end
  
  puts "✅ All parameters provided"
  true
end
```

## Advanced Parameter Techniques

### Conditional Parameters

Use ERB to make parameters conditional:

```text title="conditional_greeting.txt"
Hello [NAME]!

<% if '[ROLE]' == 'admin' %>
You have administrative privileges.
<% elsif '[ROLE]' == 'user' %>
You have standard user access.
<% else %>
Please contact support to set up your account.
<% end %>

Your last login was [LAST_LOGIN].
```

```ruby
prompt = PromptManager::Prompt.new(id: 'conditional_greeting', erb_flag: true)
prompt.parameters = {
  "[NAME]" => "Alice",
  "[ROLE]" => "admin",
  "[LAST_LOGIN]" => "2024-01-15 09:30"
}
```

### Nested Parameter Substitution

Parameters can reference other parameters:

```text title="nested_example.txt"
Welcome to [COMPANY_NAME], [USER_NAME]!

Your profile: [USER_PROFILE_URL]
Support email: [SUPPORT_EMAIL]
```

```ruby
prompt.parameters = {
  "[COMPANY_NAME]" => "Acme Corp",
  "[USER_NAME]" => "alice",
  "[USER_PROFILE_URL]" => "https://[COMPANY_NAME].com/users/[USER_NAME]".downcase,
  "[SUPPORT_EMAIL]" => "support@[COMPANY_NAME].com".downcase
}

# First pass replaces top-level parameters
# Additional processing may be needed for nested substitution
```

### Dynamic Parameter Generation

Generate parameters programmatically:

```ruby
def generate_user_parameters(user)
  {
    "[USER_ID]" => user.id.to_s,
    "[USER_NAME]" => user.full_name,
    "[USER_EMAIL]" => user.email,
    "[USER_ROLE]" => user.role.upcase,
    "[JOIN_DATE]" => user.created_at.strftime('%B %Y'),
    "[LAST_ACTIVE]" => time_ago_in_words(user.last_seen_at)
  }
end

# Usage
user = User.find(123)
prompt.parameters = generate_user_parameters(user)
```

### Parameter Validation

Implement custom validation for your parameters:

```ruby
class ParameterValidator
  def self.validate(prompt)
    errors = []
    
    prompt.parameters.each do |key, value|
      case key
      when "[EMAIL]"
        unless value =~ URI::MailTo::EMAIL_REGEXP
          errors << "#{key} must be a valid email address"
        end
      when "[DATE]"
        begin
          Date.parse(value)
        rescue ArgumentError
          errors << "#{key} must be a valid date"
        end
      when "[COUNT]"
        unless value.to_i.to_s == value && value.to_i >= 0
          errors << "#{key} must be a non-negative integer"
        end
      end
    end
    
    errors
  end
end

# Usage
errors = ParameterValidator.validate(prompt)
if errors.any?
  puts "Validation errors:"
  errors.each { |error| puts "  - #{error}" }
end
```

## Real-World Examples

### Email Template

```text title="welcome_email.txt"
Subject: Welcome to [COMPANY_NAME], [FIRST_NAME]!

Dear [FULL_NAME],

Welcome to [COMPANY_NAME]! We're excited to have you join our community.

Here are your account details:
- Username: [USERNAME]
- Email: [EMAIL]
- Account Type: [ACCOUNT_TYPE]
- Member Since: [JOIN_DATE]

Next steps:
1. Complete your profile at [PROFILE_URL]
2. Download our mobile app: [APP_STORE_URL]
3. Join our community forum: [FORUM_URL]

If you have any questions, contact us at [SUPPORT_EMAIL] or 
call [SUPPORT_PHONE].

Best regards,
[SENDER_NAME]
[SENDER_TITLE]
[COMPANY_NAME]
```

### API Documentation Template

```text title="api_doc_template.txt"
# [API_NAME] API Documentation

## Endpoint: [HTTP_METHOD] [ENDPOINT_URL]

### Description
[DESCRIPTION]

### Authentication
[AUTH_TYPE]: `[AUTH_HEADER]: [AUTH_VALUE]`

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
[PARAMETER_TABLE]

### Example Request

```[REQUEST_LANGUAGE]
[REQUEST_EXAMPLE]
```

### Example Response

```json
[RESPONSE_EXAMPLE]
```

### Error Codes

[ERROR_TABLE]

---
Last updated: [LAST_UPDATED]
API Version: [API_VERSION]
```

### Customer Support Template

```text title="support_response.txt"
//include common/support_header.txt

Dear [CUSTOMER_NAME],

Thank you for contacting [COMPANY_NAME] support regarding 
ticket #[TICKET_ID].

Issue Summary: [ISSUE_SUMMARY]
Priority Level: [PRIORITY]
Assigned Agent: [AGENT_NAME]

<% if '[PRIORITY]' == 'urgent' %>
🚨 This is marked as urgent. We're prioritizing your request 
and aim to resolve it within [URGENT_SLA] hours.
<% else %>
We aim to resolve your issue within [STANDARD_SLA] business days.
<% end %>

Our preliminary investigation shows:
[INVESTIGATION_NOTES]

Next steps:
[NEXT_STEPS]

You can track your ticket status at: [TICKET_URL]

Best regards,
[AGENT_NAME]
[COMPANY_NAME] Support Team

//include common/support_footer.txt
```

## Best Practices

### 1. Use Descriptive Keywords

```ruby
# Good - Clear and descriptive
"[USER_FIRST_NAME]", "[ORDER_TOTAL_AMOUNT]", "[DELIVERY_DATE]"

# Avoid - Ambiguous abbreviations
"[UFN]", "[OTA]", "[DD]"
```

### 2. Consistent Naming Convention

```ruby
# Choose one style and stick with it
"[USER_NAME]"      # snake_case
"[UserName]"       # PascalCase  
"[user_name]"      # lowercase

# Be consistent with plurality
"[ITEM]" + "[ITEM_COUNT]"     # Singular + count
"[ITEMS]"                     # Plural when multiple
```

### 3. Document Your Keywords

```text
# Email welcome template
# Keywords:
#   [USER_NAME] - Full display name of the user
#   [EMAIL] - User's email address  
#   [JOIN_DATE] - Date user created account (YYYY-MM-DD format)
#   [COMPANY_NAME] - Our company name

Welcome [USER_NAME]!
Your account ([EMAIL]) was created on [JOIN_DATE].
```

### 4. Provide Defaults

```ruby
def apply_defaults(prompt)
  defaults = {
    "[DATE]" => Date.today.to_s,
    "[TIME]" => Time.now.strftime('%H:%M'),
    "[COMPANY_NAME]" => "Your Company",
    "[SUPPORT_EMAIL]" => "support@yourcompany.com"
  }
  
  defaults.each do |key, value|
    prompt.parameters[key] ||= value
  end
end
```

### 5. Handle Missing Parameters Gracefully

```ruby
class SafePrompt
  def initialize(prompt)
    @prompt = prompt
  end
  
  def to_s
    text = @prompt.to_s
    
    # Check for unreplaced keywords
    unreplaced = text.scan(@prompt.class.parameter_regex).flatten
    
    if unreplaced.any?
      puts "⚠️  Warning: Unreplaced keywords: #{unreplaced.join(', ')}"
      
      # Optionally replace with placeholder
      unreplaced.each do |keyword|
        text.gsub!(keyword, "[MISSING:#{keyword}]")
      end
    end
    
    text
  end
end

# Usage
safe_prompt = SafePrompt.new(prompt)
puts safe_prompt.to_s
```

## Troubleshooting

### Keywords Not Being Replaced

1. **Check keyword format**: Ensure keywords match your regex pattern
2. **Verify parameter keys**: Keys must exactly match keywords (case-sensitive)
3. **Confirm parameter values**: Make sure values are set and not nil

### Parameter History Issues

1. **Array format**: Remember parameters are arrays since v0.3.0
2. **Access latest value**: Use `.last` to get the most recent value
3. **Backward compatibility**: Single values are automatically converted to arrays

### Performance with Large Parameter Sets

1. **Cache keyword extraction**: Don't re-parse keywords unnecessarily
2. **Batch parameter updates**: Use `merge!` instead of individual assignments
3. **Consider parameter validation**: Validate early to catch errors sooner

## Next Steps

- Learn about [Directive Processing](directive-processing.md) for including other files
- Explore [ERB Integration](erb-integration.md) for dynamic content generation  
- See [Advanced Examples](../examples/advanced.md) for complex use cases