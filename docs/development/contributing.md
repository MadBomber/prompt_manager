# Contributing to PromptManager

Thank you for your interest in contributing to PromptManager! This guide will help you get started with contributing to the project.

## Getting Started

### Prerequisites

- Ruby 3.0 or higher
- Git
- A GitHub account

### Development Setup

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/prompt_manager.git
   cd prompt_manager
   ```

3. **Install dependencies**:
   ```bash
   bundle install
   ```

4. **Run the tests** to ensure everything is working:
   ```bash
   bundle exec rspec
   ```

5. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### Code Style

We follow standard Ruby conventions and use RuboCop for code style enforcement:

```bash
# Check code style
bundle exec rubocop

# Auto-fix style issues
bundle exec rubocop -a
```

### Testing

We use RSpec for testing. Please ensure all tests pass and add tests for new features:

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/prompt_spec.rb

# Run tests with coverage
COVERAGE=true bundle exec rspec
```

### Test Coverage

We aim for high test coverage. Check coverage after running tests:

```bash
open coverage/index.html  # macOS
xdg-open coverage/index.html  # Linux
```

## Making Changes

### Adding New Features

1. **Create an issue** first to discuss the feature
2. **Write tests** for your feature (TDD approach preferred)
3. **Implement the feature** with clear, readable code
4. **Update documentation** as needed
5. **Ensure all tests pass**

### Bug Fixes

1. **Create a failing test** that reproduces the bug
2. **Fix the bug** with minimal changes
3. **Ensure the test now passes**
4. **Check for any regressions**

### Example: Adding a New Storage Adapter

```ruby
# 1. Create the adapter class
class MyCustomAdapter < PromptManager::Storage::Base
  def read(prompt_id)
    # Implementation
  end
  
  def write(prompt_id, content)
    # Implementation
  end
  
  # ... other required methods
end

# 2. Add comprehensive tests
RSpec.describe MyCustomAdapter do
  let(:adapter) { described_class.new(config_options) }
  
  include_examples 'a storage adapter'
  
  describe 'custom functionality' do
    it 'handles specific use case' do
      # Test implementation
    end
  end
end

# 3. Update documentation
# Add to docs/storage/custom-adapters.md
```

## Code Guidelines

### Ruby Style Guide

- Use 2 spaces for indentation
- Follow Ruby naming conventions (snake_case for methods and variables)
- Keep line length under 100 characters
- Use descriptive method and variable names
- Add comments for complex logic

### Architecture Principles

- **Single Responsibility**: Each class should have one clear purpose
- **Open/Closed**: Open for extension, closed for modification
- **Dependency Injection**: Avoid hard dependencies, use dependency injection
- **Error Handling**: Handle errors gracefully with meaningful messages

### Example Code Structure

```ruby
module PromptManager
  module Storage
    class CustomAdapter < Base
      # Clear initialization with validation
      def initialize(connection_string:, **options)
        validate_connection_string(connection_string)
        @connection = establish_connection(connection_string)
        super(**options)
      end
      
      # Clear method responsibilities
      def read(prompt_id)
        validate_prompt_id(prompt_id)
        
        result = @connection.get(key_for(prompt_id))
        raise PromptNotFoundError.new("Prompt '#{prompt_id}' not found") unless result
        
        result
      rescue ConnectionError => e
        raise StorageError.new("Connection failed: #{e.message}")
      end
      
      private
      
      # Helper methods are private and focused
      def validate_prompt_id(prompt_id)
        raise ArgumentError, 'prompt_id cannot be nil' if prompt_id.nil?
        raise ArgumentError, 'prompt_id cannot be empty' if prompt_id.empty?
      end
      
      def key_for(prompt_id)
        "prompts:#{prompt_id}"
      end
    end
  end
end
```

## Testing Guidelines

### Test Structure

```ruby
RSpec.describe PromptManager::Prompt do
  # Use let blocks for test setup
  let(:prompt_id) { 'test_prompt' }
  let(:storage) { instance_double(PromptManager::Storage::Base) }
  let(:prompt) { described_class.new(id: prompt_id, storage: storage) }
  
  describe '#render' do
    context 'when prompt exists' do
      before do
        allow(storage).to receive(:read)
          .with(prompt_id)
          .and_return('Hello [NAME]!')
      end
      
      it 'renders with parameters' do
        result = prompt.render(name: 'World')
        expect(result).to eq 'Hello World!'
      end
      
      it 'handles missing parameters gracefully' do
        expect {
          prompt.render
        }.to raise_error(PromptManager::MissingParametersError)
      end
    end
    
    context 'when prompt does not exist' do
      before do
        allow(storage).to receive(:read)
          .with(prompt_id)
          .and_raise(PromptManager::PromptNotFoundError)
      end
      
      it 'raises PromptNotFoundError' do
        expect {
          prompt.render
        }.to raise_error(PromptManager::PromptNotFoundError)
      end
    end
  end
end
```

### Shared Examples

Use shared examples for common behavior:

```ruby
# spec/support/shared_examples/storage_adapter.rb
RSpec.shared_examples 'a storage adapter' do
  describe 'required interface' do
    it 'implements read method' do
      expect(adapter).to respond_to(:read)
    end
    
    it 'implements write method' do
      expect(adapter).to respond_to(:write)
    end
    
    it 'implements exist? method' do
      expect(adapter).to respond_to(:exist?)
    end
  end
  
  describe 'basic functionality' do
    let(:prompt_id) { 'test_prompt' }
    let(:content) { 'Hello [NAME]!' }
    
    it 'stores and retrieves content' do
      adapter.write(prompt_id, content)
      expect(adapter.read(prompt_id)).to eq content
    end
  end
end
```

## Documentation

### Code Documentation

Use YARD for inline documentation:

```ruby
# Renders a prompt with the given parameters
#
# @param parameters [Hash] Key-value pairs for parameter substitution
# @return [String] The rendered prompt content
# @raise [PromptNotFoundError] If the prompt cannot be found
# @raise [MissingParametersError] If required parameters are missing
#
# @example Basic usage
#   prompt = PromptManager::Prompt.new(id: 'welcome')
#   result = prompt.render(name: 'John', company: 'Acme Corp')
#
# @example With nested parameters
#   prompt.render(user: { name: 'Jane', email: 'jane@example.com' })
def render(parameters = {})
  # Implementation
end
```

### README Updates

Update the main README.md if your changes affect:
- Installation instructions
- Basic usage examples
- Configuration options
- Major features

### Changelog

Add entries to CHANGELOG.md for:
- New features
- Bug fixes
- Breaking changes
- Deprecations

Format:
```markdown
## [Unreleased]

### Added
- New feature description

### Changed
- Changed behavior description

### Fixed
- Bug fix description

### Deprecated
- Deprecated feature description
```

## Submitting Changes

### Before Submitting

1. **Ensure all tests pass**: `bundle exec rspec`
2. **Check code style**: `bundle exec rubocop`
3. **Update documentation** as needed
4. **Add changelog entry** if applicable
5. **Rebase your branch** on the latest main branch

### Pull Request Guidelines

1. **Create a clear title**: "Add Redis storage adapter" or "Fix parameter parsing bug"

2. **Write a detailed description**:
   ```markdown
   ## Summary
   Brief description of what this PR does
   
   ## Changes
   - Specific change 1
   - Specific change 2
   
   ## Testing
   - Added tests for new functionality
   - All existing tests pass
   
   ## Documentation
   - Updated relevant documentation files
   ```

3. **Link related issues**: "Closes #123" or "Fixes #456"

4. **Request appropriate reviewers**

### Pull Request Checklist

- [ ] Tests added/updated and passing
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] Changelog updated (if applicable)
- [ ] No merge conflicts with main branch
- [ ] PR description is clear and complete

## Development Resources

### Project Structure

```
prompt_manager/
├── lib/
│   └── prompt_manager/
│       ├── prompt.rb              # Core Prompt class
│       ├── storage/               # Storage adapters
│       ├── directive_processor.rb # Directive processing
│       └── configuration.rb      # Configuration management
├── spec/                          # Test files
│   ├── prompt_manager/
│   ├── support/                   # Test helpers
│   └── fixtures/                  # Test data
├── docs/                          # Documentation
└── examples/                      # Usage examples
```

### Key Classes and Modules

- `PromptManager::Prompt` - Main interface for prompt operations
- `PromptManager::Storage::Base` - Abstract storage adapter
- `PromptManager::DirectiveProcessor` - Handles `//include` and custom directives
- `PromptManager::Configuration` - Configuration management

### Common Development Tasks

```bash
# Run tests for specific component
bundle exec rspec spec/prompt_manager/storage/

# Generate test coverage report
COVERAGE=true bundle exec rspec

# Check for security vulnerabilities
bundle audit

# Update dependencies
bundle update

# Generate documentation
yard doc
```

## Getting Help

- **GitHub Issues**: For bug reports and feature requests
- **Discussions**: For questions and general discussion
- **Email**: For security-related issues

## Recognition

Contributors are recognized in:
- `CONTRIBUTORS.md` file
- Release notes for major contributions
- GitHub contributor statistics

Thank you for contributing to PromptManager! 🎉