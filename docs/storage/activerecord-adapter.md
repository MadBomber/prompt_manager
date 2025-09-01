# ActiveRecordAdapter

The ActiveRecordAdapter allows you to store prompts in a relational database using ActiveRecord, perfect for Rails applications and scenarios requiring database-backed prompt storage.

## Overview

Store prompts in your application's database alongside other application data. This adapter provides full CRUD operations, query capabilities, and integration with ActiveRecord models.

## Setup

### Migration

Create the prompts table:

```ruby
# Generate migration
rails generate migration CreatePrompts

# In the migration file:
class CreatePrompts < ActiveRecord::Migration[7.0]
  def change
    create_table :prompts do |t|
      t.string :prompt_id, null: false, index: { unique: true }
      t.text :content, null: false
      t.text :description
      t.json :metadata, default: {}
      t.timestamps
    end
  end
end
```

### Model

```ruby
# app/models/prompt.rb
class Prompt < ApplicationRecord
  validates :prompt_id, presence: true, uniqueness: true
  validates :content, presence: true
  
  # Optional: Add scopes for organization
  scope :by_category, ->(category) { where("metadata->>'category' = ?", category) }
  scope :recent, -> { order(updated_at: :desc) }
end
```

### Configuration

```ruby
# Configure PromptManager to use ActiveRecord
PromptManager.configure do |config|
  config.storage = PromptManager::Storage::ActiveRecordAdapter.new(
    model_class: Prompt,
    id_column: :prompt_id,
    content_column: :content
  )
end
```

## Basic Usage

### Creating Prompts

```ruby
# Create via PromptManager
prompt = PromptManager::Prompt.new(id: 'welcome_email')
prompt.save(
  content: 'Welcome to our service, [USER_NAME]!',
  metadata: {
    category: 'email',
    author: 'marketing_team',
    version: '1.0'
  }
)

# Or create via ActiveRecord
Prompt.create!(
  prompt_id: 'goodbye_email',
  content: 'Thanks for using our service, [USER_NAME]!',
  description: 'Farewell email template',
  metadata: { category: 'email', priority: 'low' }
)
```

### Reading Prompts

```ruby
# Via PromptManager (recommended)
prompt = PromptManager::Prompt.new(id: 'welcome_email')
result = prompt.render(user_name: 'Alice')

# Via ActiveRecord
prompt_record = Prompt.find_by(prompt_id: 'welcome_email')
puts prompt_record.content
```

### Updating Prompts

```ruby
# Via PromptManager
prompt = PromptManager::Prompt.new(id: 'welcome_email')
prompt.save('Updated content: Welcome [USER_NAME] to our platform!')

# Via ActiveRecord
prompt_record = Prompt.find_by(prompt_id: 'welcome_email')
prompt_record.update!(
  content: 'Updated content...',
  metadata: prompt_record.metadata.merge(version: '1.1')
)
```

## Advanced Features

### Query Interface

```ruby
# Configure with query support
PromptManager.configure do |config|
  config.storage = PromptManager::Storage::ActiveRecordAdapter.new(
    model_class: Prompt,
    id_column: :prompt_id,
    content_column: :content,
    enable_queries: true
  )
end

# Search prompts
results = PromptManager.storage.search(
  category: 'email',
  content_contains: 'welcome'
)

# List by metadata
email_prompts = PromptManager.storage.where(
  "metadata->>'category' = ?", 'email'
)
```

### Versioning

```ruby
# Add versioning to your model
class Prompt < ApplicationRecord
  has_many :prompt_versions, dependent: :destroy
  
  before_update :create_version
  
  private
  
  def create_version
    if content_changed?
      prompt_versions.create!(
        content: content_was,
        version_number: (prompt_versions.maximum(:version_number) || 0) + 1,
        created_at: updated_at_was
      )
    end
  end
end

# Version model
class PromptVersion < ApplicationRecord
  belongs_to :prompt
end

# Migration for versions
class CreatePromptVersions < ActiveRecord::Migration[7.0]
  def change
    create_table :prompt_versions do |t|
      t.references :prompt, null: false, foreign_key: true
      t.text :content, null: false
      t.integer :version_number, null: false
      t.timestamps
    end
    
    add_index :prompt_versions, [:prompt_id, :version_number], unique: true
  end
end
```

### Multi-tenancy

```ruby
# Add tenant support
class Prompt < ApplicationRecord
  belongs_to :tenant
  
  validates :prompt_id, uniqueness: { scope: :tenant_id }
  
  scope :for_tenant, ->(tenant) { where(tenant: tenant) }
end

# Configure with tenant scope
PromptManager.configure do |config|
  config.storage = PromptManager::Storage::ActiveRecordAdapter.new(
    model_class: Prompt,
    id_column: :prompt_id,
    content_column: :content,
    scope: -> { Prompt.for_tenant(Current.tenant) }
  )
end
```

## Performance Optimization

### Indexing

```ruby
# Add performance indexes
class AddPromptIndexes < ActiveRecord::Migration[7.0]
  def change
    add_index :prompts, :prompt_id, unique: true
    add_index :prompts, :updated_at
    add_index :prompts, "((metadata->>'category'))", name: 'index_prompts_on_category'
    add_index :prompts, :content, type: :gin  # For full-text search (PostgreSQL)
  end
end
```

### Caching

```ruby
# Configure caching
PromptManager.configure do |config|
  config.storage = PromptManager::Storage::ActiveRecordAdapter.new(
    model_class: Prompt,
    id_column: :prompt_id,
    content_column: :content,
    cache_queries: true,
    cache_ttl: 300  # 5 minutes
  )
end

# Add caching to your model
class Prompt < ApplicationRecord
  after_update :clear_cache
  after_destroy :clear_cache
  
  private
  
  def clear_cache
    Rails.cache.delete("prompt:#{prompt_id}")
  end
end
```

### Connection Pooling

```ruby
# For high-traffic applications
class PromptReadOnlyRecord < ApplicationRecord
  self.abstract_class = true
  connects_to database: { reading: :prompt_replica }
end

class Prompt < PromptReadOnlyRecord
  # Read operations use replica database
end
```

## Integration Examples

### Rails Controller

```ruby
class PromptsController < ApplicationController
  def show
    prompt = PromptManager::Prompt.new(id: params[:id])
    @content = prompt.render(params.permit(:user_name, :product_name))
  rescue PromptManager::PromptNotFoundError
    render json: { error: 'Prompt not found' }, status: 404
  end
  
  def create
    prompt = PromptManager::Prompt.new(id: prompt_params[:id])
    prompt.save(prompt_params[:content])
    
    render json: { message: 'Prompt created successfully' }
  rescue => e
    render json: { error: e.message }, status: 422
  end
  
  private
  
  def prompt_params
    params.require(:prompt).permit(:id, :content, :description, metadata: {})
  end
end
```

### Background Jobs

```ruby
class ProcessPromptJob < ApplicationJob
  def perform(prompt_id, parameters)
    prompt = PromptManager::Prompt.new(id: prompt_id)
    result = prompt.render(parameters)
    
    # Process the result
    NotificationService.send_message(result)
  rescue PromptManager::PromptNotFoundError => e
    logger.error "Prompt not found: #{prompt_id}"
    # Handle gracefully
  end
end

# Usage
ProcessPromptJob.perform_later('daily_report', user_id: user.id)
```

## Best Practices

1. **Use Transactions**: Wrap prompt operations in database transactions
2. **Validate Content**: Add model validations for prompt content
3. **Index Strategically**: Index frequently queried fields
4. **Cache Wisely**: Cache frequently accessed prompts
5. **Monitor Performance**: Track database query performance
6. **Backup Regularly**: Include prompts in your database backup strategy
7. **Version Control**: Consider versioning for important prompts
8. **Secure Access**: Use database-level permissions and encryption

## Migration from FileSystem

```ruby
# Migrate from filesystem to database
class MigratePromptsToDatabase
  def self.perform(prompts_dir)
    Dir.glob(File.join(prompts_dir, '**/*.txt')).each do |file_path|
      relative_path = Pathname.new(file_path).relative_path_from(Pathname.new(prompts_dir))
      prompt_id = relative_path.sub_ext('').to_s
      content = File.read(file_path)
      
      Prompt.create!(
        prompt_id: prompt_id,
        content: content,
        description: "Migrated from #{file_path}",
        metadata: {
          original_file: file_path,
          migrated_at: Time.current
        }
      )
    end
  end
end

# Run migration
MigratePromptsToDatabase.perform('/path/to/prompts')
```