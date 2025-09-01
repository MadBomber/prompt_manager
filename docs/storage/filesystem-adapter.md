# FileSystemAdapter

The FileSystemAdapter is the default storage adapter for PromptManager, storing prompts as files in a directory structure.

## Overview

The FileSystemAdapter stores prompts as individual text files in a configurable directory. This is the simplest and most common storage method.

## Configuration

### Basic Setup

```ruby
require 'prompt_manager'

# Use default filesystem storage (~/prompts_dir/)
prompt = PromptManager::Prompt.new(id: 'welcome_message')
```

### Custom Directory

```ruby
PromptManager.configure do |config|
  config.storage = PromptManager::Storage::FileSystemAdapter.new(
    prompts_dir: '/path/to/your/prompts'
  )
end
```

### Multiple Directories

```ruby
# Search multiple directories in order
PromptManager.configure do |config|
  config.storage = PromptManager::Storage::FileSystemAdapter.new(
    prompts_dir: [
      '/home/user/project_prompts',
      '/shared/common_prompts',
      '/system/default_prompts'
    ]
  )
end
```

## Directory Structure

### Basic Structure

```
prompts_dir/
├── welcome_message.txt
├── error_response.txt
├── customer_service/
│   ├── greeting.txt
│   └── farewell.txt
└── templates/
    ├── email_header.txt
    └── email_footer.txt
```

### Organizing Prompts

```ruby
# Access nested prompts using path separators
customer_greeting = PromptManager::Prompt.new(id: 'customer_service/greeting')
email_header = PromptManager::Prompt.new(id: 'templates/email_header')
```

## File Operations

### Creating Prompts

```ruby
# Prompts are created as .txt files
prompt = PromptManager::Prompt.new(id: 'new_prompt')
prompt.save("Your prompt content here...")
# Creates: prompts_dir/new_prompt.txt
```

### Reading Prompts

```ruby
# Automatically reads from filesystem
prompt = PromptManager::Prompt.new(id: 'existing_prompt')
content = prompt.render
```

### Updating Prompts

```ruby
# Modify the file directly or use save method
prompt = PromptManager::Prompt.new(id: 'existing_prompt')
prompt.save("Updated content...")
```

### Deleting Prompts

```ruby
# Remove the prompt file
prompt = PromptManager::Prompt.new(id: 'old_prompt')
prompt.delete
```

## Advanced Features

### File Extensions

The adapter supports different file extensions:

```ruby
# These all work:
# - welcome.txt
# - welcome.md
# - welcome.prompt
# - welcome (no extension)

prompt = PromptManager::Prompt.new(id: 'welcome')
# Searches for welcome.txt, then welcome.md, etc.
```

### Directory Search Order

When using multiple directories, the adapter searches in order:

```ruby
config.storage = PromptManager::Storage::FileSystemAdapter.new(
  prompts_dir: [
    './project_prompts',    # First priority
    '~/shared_prompts',     # Second priority  
    '/system/prompts'       # Last resort
  ]
)
```

### Permissions and Security

```ruby
# Set directory permissions
config.storage = PromptManager::Storage::FileSystemAdapter.new(
  prompts_dir: '/secure/prompts',
  file_mode: 0600,      # Read/write for owner only
  dir_mode: 0700        # Access for owner only
)
```

## Error Handling

### Common Issues

```ruby
begin
  prompt = PromptManager::Prompt.new(id: 'missing_prompt')
rescue PromptManager::PromptNotFoundError => e
  puts "Prompt file not found: #{e.message}"
end

begin
  prompt.save("content")
rescue PromptManager::StorageError => e
  puts "Cannot write file: #{e.message}"
  # Check permissions, disk space, etc.
end
```

### File System Monitoring

```ruby
# Watch for file changes (requires additional gems)
require 'listen'

listener = Listen.to('/path/to/prompts') do |modified, added, removed|
  puts "Prompts changed: #{modified + added + removed}"
  # Reload prompts if needed
end

listener.start
```

## Performance Considerations

### Caching

```ruby
# Enable file content caching
PromptManager.configure do |config|
  config.cache_prompts = true
  config.cache_ttl = 300  # 5 minutes
end
```

### Large Directories

For directories with many prompts:

```ruby
# Use indexing for faster lookups
config.storage = PromptManager::Storage::FileSystemAdapter.new(
  prompts_dir: '/large/prompt/directory',
  enable_indexing: true,
  index_file: '.prompt_index'
)
```

## Best Practices

1. **Organize by Purpose**: Use subdirectories to group related prompts
2. **Consistent Naming**: Use clear, descriptive prompt IDs
3. **Version Control**: Store your prompts directory in git
4. **Backup Strategy**: Regular backups of your prompts directory
5. **File Permissions**: Secure sensitive prompts with appropriate permissions
6. **Documentation**: Use comments in prompt files to document purpose and usage

## Migration from Other Storage

### From Database

```ruby
# Export database prompts to filesystem
database_adapter.all_prompts.each do |prompt_id, content|
  file_path = File.join(prompts_dir, "#{prompt_id}.txt")
  File.write(file_path, content)
end
```

### Bulk Import

```ruby
# Import multiple files
Dir.glob('/old/prompts/*.txt').each do |file_path|
  prompt_id = File.basename(file_path, '.txt')
  content = File.read(file_path)
  
  prompt = PromptManager::Prompt.new(id: prompt_id)
  prompt.save(content)
end
```