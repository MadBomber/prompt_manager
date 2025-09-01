# Testing Guide

This guide covers testing strategies, patterns, and best practices for PromptManager development.

## Test Framework Setup

### RSpec Configuration

```ruby
# spec/spec_helper.rb
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  minimum_coverage 90
end

require 'prompt_manager'
require 'rspec'
require 'webmock/rspec'

RSpec.configure do |config|
  # Use expect syntax only
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
  
  # Mock framework
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  
  # Shared examples and helpers
  config.shared_context_metadata_behavior = :apply_to_host_groups
  
  # Test isolation
  config.before(:each) do
    # Reset PromptManager configuration
    PromptManager.reset_configuration!
    
    # Clear any cached data
    if defined?(Rails) && Rails.cache
      Rails.cache.clear
    end
  end
  
  config.after(:each) do
    # Clean up test files
    FileUtils.rm_rf('tmp/test_prompts') if Dir.exist?('tmp/test_prompts')
  end
end

# Load support files
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }
```

### Test Support Files

```ruby
# spec/support/shared_examples/storage_adapter.rb
RSpec.shared_examples 'a storage adapter' do
  let(:prompt_id) { 'test_prompt' }
  let(:content) { 'Hello [NAME]!' }
  let(:updated_content) { 'Updated: [NAME]!' }
  
  describe 'required interface' do
    it 'implements all required methods' do
      expect(adapter).to respond_to(:read)
      expect(adapter).to respond_to(:write)
      expect(adapter).to respond_to(:exist?)
      expect(adapter).to respond_to(:delete)
      expect(adapter).to respond_to(:list)
    end
  end
  
  describe '#write and #read' do
    it 'stores and retrieves content' do
      expect(adapter.write(prompt_id, content)).to be true
      expect(adapter.read(prompt_id)).to eq content
    end
    
    it 'overwrites existing content' do
      adapter.write(prompt_id, content)
      adapter.write(prompt_id, updated_content)
      expect(adapter.read(prompt_id)).to eq updated_content
    end
    
    it 'raises PromptNotFoundError for non-existent prompts' do
      expect {
        adapter.read('non_existent')
      }.to raise_error(PromptManager::PromptNotFoundError)
    end
  end
  
  describe '#exist?' do
    it 'returns false for non-existent prompts' do
      expect(adapter.exist?('non_existent')).to be false
    end
    
    it 'returns true for existing prompts' do
      adapter.write(prompt_id, content)
      expect(adapter.exist?(prompt_id)).to be true
    end
  end
  
  describe '#delete' do
    context 'when prompt exists' do
      before { adapter.write(prompt_id, content) }
      
      it 'removes the prompt' do
        expect(adapter.delete(prompt_id)).to be true
        expect(adapter.exist?(prompt_id)).to be false
      end
    end
    
    context 'when prompt does not exist' do
      it 'returns false' do
        expect(adapter.delete('non_existent')).to be false
      end
    end
  end
  
  describe '#list' do
    it 'returns empty array when no prompts exist' do
      expect(adapter.list).to eq []
    end
    
    it 'returns all prompt IDs' do
      adapter.write('prompt1', 'content1')
      adapter.write('prompt2', 'content2')
      
      expect(adapter.list).to contain_exactly('prompt1', 'prompt2')
    end
  end
end

# spec/support/helpers/prompt_helpers.rb
module PromptHelpers
  def create_test_prompt(id, content, storage: nil)
    storage ||= test_storage
    storage.write(id, content)
    
    PromptManager::Prompt.new(id: id, storage: storage)
  end
  
  def test_storage
    @test_storage ||= PromptManager::Storage::FileSystemAdapter.new(
      prompts_dir: 'tmp/test_prompts'
    )
  end
  
  def create_test_storage_with_prompts(prompts = {})
    storage = test_storage
    prompts.each { |id, content| storage.write(id, content) }
    storage
  end
end

RSpec.configure do |config|
  config.include PromptHelpers
end
```

## Unit Testing

### Testing the Prompt Class

```ruby
# spec/prompt_manager/prompt_spec.rb
RSpec.describe PromptManager::Prompt do
  let(:prompt_id) { 'test_prompt' }
  let(:storage) { instance_double(PromptManager::Storage::Base) }
  let(:prompt) { described_class.new(id: prompt_id, storage: storage) }
  
  describe '#initialize' do
    it 'requires an id parameter' do
      expect {
        described_class.new
      }.to raise_error(ArgumentError)
    end
    
    it 'accepts optional parameters' do
      prompt = described_class.new(
        id: 'test',
        erb_flag: true,
        envar_flag: true
      )
      
      expect(prompt.id).to eq 'test'
      expect(prompt.erb_flag).to be true
      expect(prompt.envar_flag).to be true
    end
  end
  
  describe '#render' do
    context 'with simple parameter substitution' do
      let(:content) { 'Hello [NAME]!' }
      
      before do
        allow(storage).to receive(:read).with(prompt_id).and_return(content)
      end
      
      it 'substitutes parameters' do
        result = prompt.render(name: 'World')
        expect(result).to eq 'Hello World!'
      end
      
      it 'handles missing parameters' do
        expect {
          prompt.render
        }.to raise_error(PromptManager::MissingParametersError) do |error|
          expect(error.missing_parameters).to contain_exactly('NAME')
        end
      end
      
      it 'preserves case in parameter names' do
        content = 'Hello [name] and [NAME]!'
        allow(storage).to receive(:read).with(prompt_id).and_return(content)
        
        result = prompt.render(name: 'Alice', NAME: 'BOB')
        expect(result).to eq 'Hello Alice and BOB!'
      end
    end
    
    context 'with nested parameters' do
      let(:content) { 'User: [USER.NAME] ([USER.EMAIL])' }
      
      before do
        allow(storage).to receive(:read).with(prompt_id).and_return(content)
      end
      
      it 'handles nested hash parameters' do
        result = prompt.render(
          user: {
            name: 'John Doe',
            email: 'john@example.com'
          }
        )
        
        expect(result).to eq 'User: John Doe (john@example.com)'
      end
      
      it 'handles missing nested parameters' do
        expect {
          prompt.render(user: { name: 'John' })
        }.to raise_error(PromptManager::MissingParametersError) do |error|
          expect(error.missing_parameters).to include('USER.EMAIL')
        end
      end
    end
    
    context 'with array parameters' do
      let(:content) { 'Items: [ITEMS]' }
      
      before do
        allow(storage).to receive(:read).with(prompt_id).and_return(content)
      end
      
      it 'joins array elements with commas' do
        result = prompt.render(items: ['Apple', 'Banana', 'Cherry'])
        expect(result).to eq 'Items: Apple, Banana, Cherry'
      end
      
      it 'handles empty arrays' do
        result = prompt.render(items: [])
        expect(result).to eq 'Items: '
      end
    end
    
    context 'with ERB processing' do
      let(:prompt) { described_class.new(id: prompt_id, storage: storage, erb_flag: true) }
      let(:content) { 'Today is <%= Date.today.strftime("%B %d, %Y") %>' }
      
      before do
        allow(storage).to receive(:read).with(prompt_id).and_return(content)
        allow(Date).to receive(:today).and_return(Date.new(2024, 1, 15))
      end
      
      it 'processes ERB templates' do
        result = prompt.render
        expect(result).to eq 'Today is January 15, 2024'
      end
    end
  end
  
  describe '#parameters' do
    before do
      allow(storage).to receive(:read)
        .with(prompt_id)
        .and_return('Hello [NAME], your order [ORDER_ID] is ready!')
    end
    
    it 'extracts parameter names from content' do
      expect(prompt.parameters).to contain_exactly('NAME', 'ORDER_ID')
    end
  end
  
  describe '#content' do
    let(:expected_content) { 'Raw prompt content' }
    
    before do
      allow(storage).to receive(:read).with(prompt_id).and_return(expected_content)
    end
    
    it 'returns raw content from storage' do
      expect(prompt.content).to eq expected_content
    end
  end
  
  describe 'error handling' do
    it 'raises PromptNotFoundError when prompt does not exist' do
      allow(storage).to receive(:read)
        .with(prompt_id)
        .and_raise(PromptManager::PromptNotFoundError.new("Prompt not found"))
      
      expect {
        prompt.render
      }.to raise_error(PromptManager::PromptNotFoundError)
    end
  end
end
```

### Testing Storage Adapters

```ruby
# spec/prompt_manager/storage/file_system_adapter_spec.rb
RSpec.describe PromptManager::Storage::FileSystemAdapter do
  let(:test_dir) { 'tmp/test_prompts' }
  let(:adapter) { described_class.new(prompts_dir: test_dir) }
  
  before do
    FileUtils.mkdir_p(test_dir)
  end
  
  after do
    FileUtils.rm_rf(test_dir)
  end
  
  include_examples 'a storage adapter'
  
  describe 'file system specific behavior' do
    describe '#initialize' do
      it 'creates directory if it does not exist' do
        new_dir = 'tmp/new_prompts'
        expect(Dir.exist?(new_dir)).to be false
        
        described_class.new(prompts_dir: new_dir)
        expect(Dir.exist?(new_dir)).to be true
        
        FileUtils.rm_rf(new_dir)
      end
      
      it 'accepts multiple directories' do
        dirs = ['tmp/prompts1', 'tmp/prompts2']
        adapter = described_class.new(prompts_dir: dirs)
        
        dirs.each do |dir|
          expect(Dir.exist?(dir)).to be true
          FileUtils.rm_rf(dir)
        end
      end
    end
    
    describe 'file extensions' do
      it 'finds .txt files' do
        File.write(File.join(test_dir, 'test.txt'), 'content')
        expect(adapter.exist?('test')).to be true
      end
      
      it 'finds .md files' do
        File.write(File.join(test_dir, 'test.md'), 'content')
        expect(adapter.exist?('test')).to be true
      end
      
      it 'prioritizes .txt over .md' do
        File.write(File.join(test_dir, 'test.txt'), 'txt content')
        File.write(File.join(test_dir, 'test.md'), 'md content')
        
        expect(adapter.read('test')).to eq 'txt content'
      end
    end
    
    describe 'subdirectories' do
      it 'handles nested prompt IDs' do
        subdir = File.join(test_dir, 'emails')
        FileUtils.mkdir_p(subdir)
        File.write(File.join(subdir, 'welcome.txt'), 'Welcome!')
        
        expect(adapter.read('emails/welcome')).to eq 'Welcome!'
      end
    end
  end
end

# spec/prompt_manager/storage/active_record_adapter_spec.rb
RSpec.describe PromptManager::Storage::ActiveRecordAdapter do
  # Mock ActiveRecord model
  let(:model_class) do
    Class.new do
      def self.name
        'TestPrompt'
      end
      
      attr_accessor :prompt_id, :content
      
      def initialize(attributes = {})
        attributes.each { |key, value| send("#{key}=", value) }
      end
      
      def save!
        # Mock save
      end
      
      def destroy!
        # Mock destroy
      end
      
      # Mock class methods
      def self.find_by(conditions)
        # Override in tests
      end
      
      def self.where(conditions)
        # Override in tests  
      end
      
      def self.pluck(*columns)
        # Override in tests
      end
    end
  end
  
  let(:adapter) { described_class.new(model_class: model_class) }
  
  include_examples 'a storage adapter' do
    # Setup mock expectations for shared examples
    before do
      @records = {}
      
      allow(model_class).to receive(:find_by) do |conditions|
        id = conditions[:prompt_id]
        record_data = @records[id]
        record_data ? model_class.new(record_data) : nil
      end
      
      allow(model_class).to receive(:create!) do |attributes|
        @records[attributes[:prompt_id]] = attributes
        model_class.new(attributes)
      end
      
      allow_any_instance_of(model_class).to receive(:update!) do |instance, attributes|
        @records[instance.prompt_id].merge!(attributes)
      end
      
      allow_any_instance_of(model_class).to receive(:destroy!) do |instance|
        @records.delete(instance.prompt_id)
      end
      
      allow(model_class).to receive(:pluck) do |*columns|
        @records.values.map { |record| columns.map { |col| record[col] } }
      end
    end
  end
end
```

## Integration Testing

### Full Stack Integration Tests

```ruby
# spec/integration/prompt_rendering_spec.rb
RSpec.describe 'Prompt Rendering Integration' do
  let(:test_dir) { 'tmp/integration_test' }
  let(:storage) { PromptManager::Storage::FileSystemAdapter.new(prompts_dir: test_dir) }
  
  before do
    FileUtils.mkdir_p(test_dir)
    FileUtils.mkdir_p(File.join(test_dir, 'common'))
    
    # Create test prompts
    File.write(
      File.join(test_dir, 'common', 'header.txt'),
      'Company: [COMPANY_NAME]'
    )
    
    File.write(
      File.join(test_dir, 'email_template.txt'),
      "//include common/header.txt\n\nDear [CUSTOMER_NAME],\nYour order [ORDER_ID] is ready!"
    )
    
    File.write(
      File.join(test_dir, 'erb_template.txt'),
      "<%= erb_flag = true %>\nGenerated at: <%= Time.current.strftime('%Y-%m-%d') %>\nHello [NAME]!"
    )
    
    PromptManager.configure do |config|
      config.storage = storage
    end
  end
  
  after do
    FileUtils.rm_rf(test_dir)
  end
  
  describe 'directive processing' do
    it 'processes includes and parameter substitution' do
      prompt = PromptManager::Prompt.new(id: 'email_template')
      
      result = prompt.render(
        company_name: 'Acme Corp',
        customer_name: 'John Doe',
        order_id: 'ORD-123'
      )
      
      expect(result).to eq "Company: Acme Corp\n\nDear John Doe,\nYour order ORD-123 is ready!"
    end
  end
  
  describe 'ERB processing' do
    it 'processes ERB templates with parameters' do
      prompt = PromptManager::Prompt.new(id: 'erb_template', erb_flag: true)
      
      # Mock Time.current for consistent testing
      allow(Time).to receive(:current).and_return(Time.parse('2024-01-15 10:00:00'))
      
      result = prompt.render(name: 'Alice')
      
      expect(result).to eq "Generated at: 2024-01-15\nHello Alice!"
    end
  end
  
  describe 'error scenarios' do
    it 'handles missing includes gracefully' do
      File.write(
        File.join(test_dir, 'broken_template.txt'),
        "//include non_existent.txt\nContent"
      )
      
      prompt = PromptManager::Prompt.new(id: 'broken_template')
      
      expect {
        prompt.render
      }.to raise_error(PromptManager::DirectiveProcessingError)
    end
  end
end
```

## Performance Testing

### Benchmark Tests

```ruby
# spec/performance/rendering_performance_spec.rb
require 'benchmark/ips'

RSpec.describe 'Rendering Performance' do
  let(:storage) { create_test_storage_with_prompts(test_prompts) }
  
  let(:test_prompts) do
    {
      'simple' => 'Hello [NAME]!',
      'complex' => (1..100).map { |i| "Line #{i}: [PARAM_#{i}]" }.join("\n"),
      'with_include' => "//include simple\nAdditional content: [VALUE]"
    }
  end
  
  let(:simple_params) { { name: 'John' } }
  let(:complex_params) do
    (1..100).each_with_object({}) { |i, hash| hash["param_#{i}".to_sym] = "value_#{i}" }
  end
  
  describe 'simple prompt rendering' do
    it 'renders efficiently' do
      prompt = PromptManager::Prompt.new(id: 'simple', storage: storage)
      
      expect {
        prompt.render(simple_params)
      }.to perform_under(0.001).sec
    end
  end
  
  describe 'complex prompt rendering' do
    it 'handles many parameters efficiently' do
      prompt = PromptManager::Prompt.new(id: 'complex', storage: storage)
      
      expect {
        prompt.render(complex_params)
      }.to perform_under(0.01).sec
    end
  end
  
  describe 'bulk rendering performance' do
    it 'processes multiple prompts efficiently' do
      prompts = Array.new(100) { PromptManager::Prompt.new(id: 'simple', storage: storage) }
      
      expect {
        prompts.each { |prompt| prompt.render(simple_params) }
      }.to perform_under(0.1).sec
    end
  end
  
  # Benchmark comparison
  it 'compares different rendering strategies', :benchmark do
    prompt = PromptManager::Prompt.new(id: 'simple', storage: storage)
    
    Benchmark.ips do |x|
      x.config(time: 2, warmup: 1)
      
      x.report('direct render') do
        prompt.render(simple_params)
      end
      
      x.report('cached render') do
        CachedPromptManager.render('simple', simple_params)
      end
      
      x.compare!
    end
  end
end
```

### Memory Usage Tests

```ruby
# spec/performance/memory_usage_spec.rb
RSpec.describe 'Memory Usage' do
  def measure_memory_usage
    GC.start
    before = GC.stat[:heap_allocated_pages]
    
    yield
    
    GC.start
    after = GC.stat[:heap_allocated_pages]
    
    (after - before) * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE]
  end
  
  it 'does not leak memory during rendering' do
    storage = create_test_storage_with_prompts({
      'test' => 'Hello [NAME]!'
    })
    
    prompt = PromptManager::Prompt.new(id: 'test', storage: storage)
    
    memory_used = measure_memory_usage do
      1000.times do
        prompt.render(name: 'Test')
      end
    end
    
    # Should not use excessive memory (adjust threshold as needed)
    expect(memory_used).to be < 10 * 1024 * 1024 # 10MB
  end
end
```

## Mock and Stub Patterns

### Storage Mocking

```ruby
# spec/support/storage_mocks.rb
module StorageMocks
  def mock_storage_with_prompts(prompts = {})
    storage = instance_double(PromptManager::Storage::Base)
    
    # Mock read method
    allow(storage).to receive(:read) do |prompt_id|
      content = prompts[prompt_id]
      if content
        content
      else
        raise PromptManager::PromptNotFoundError.new("Prompt '#{prompt_id}' not found")
      end
    end
    
    # Mock exist? method
    allow(storage).to receive(:exist?) do |prompt_id|
      prompts.key?(prompt_id)
    end
    
    # Mock write method
    allow(storage).to receive(:write) do |prompt_id, content|
      prompts[prompt_id] = content
      true
    end
    
    # Mock delete method
    allow(storage).to receive(:delete) do |prompt_id|
      prompts.delete(prompt_id) ? true : false
    end
    
    # Mock list method
    allow(storage).to receive(:list) { prompts.keys }
    
    storage
  end
end

RSpec.configure do |config|
  config.include StorageMocks
end
```

### External Service Mocking

```ruby
# For testing prompts that make external API calls
RSpec.describe 'API Integration Prompts' do
  before do
    # Mock HTTP calls
    stub_request(:get, 'https://api.example.com/users/123')
      .to_return(
        status: 200,
        body: { name: 'John Doe', email: 'john@example.com' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
  it 'handles API responses in prompts' do
    # Test prompt that makes API calls
  end
end
```

## Test Data Management

### Fixtures

```ruby
# spec/fixtures/prompts.yml
simple_greeting:
  id: 'simple_greeting'
  content: 'Hello [NAME]!'

complex_email:
  id: 'complex_email'
  content: |
    //include headers/email_header.txt
    
    Dear [CUSTOMER.NAME],
    
    Your order #[ORDER.ID] has been processed.
    
    //include footers/email_footer.txt

# spec/support/fixture_helpers.rb
module FixtureHelpers
  def load_prompt_fixtures
    YAML.load_file(File.join(__dir__, '..', 'fixtures', 'prompts.yml'))
  end
  
  def create_prompt_from_fixture(fixture_name)
    fixtures = load_prompt_fixtures
    fixture = fixtures[fixture_name.to_s]
    
    storage = mock_storage_with_prompts(fixture['id'] => fixture['content'])
    PromptManager::Prompt.new(id: fixture['id'], storage: storage)
  end
end
```

## Continuous Integration

### GitHub Actions Test Configuration

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        ruby-version: ['3.0', '3.1', '3.2']
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Ruby ${{ matrix.ruby-version }}
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: ${{ matrix.ruby-version }}
        bundler-cache: true
    
    - name: Run tests
      run: |
        bundle exec rspec --format progress --format RspecJunitFormatter --out tmp/test-results.xml
    
    - name: Check test coverage
      run: |
        bundle exec rspec
        if [ -f coverage/.resultset.json ]; then
          echo "Coverage report generated"
        fi
    
    - name: Upload test results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results-${{ matrix.ruby-version }}
        path: tmp/test-results.xml
```

## Best Practices

1. **Test Isolation**: Each test should be independent and not rely on other tests
2. **Clear Naming**: Test names should clearly describe what is being tested
3. **Arrange-Act-Assert**: Structure tests with clear setup, action, and verification phases
4. **Mock External Dependencies**: Don't rely on external services in unit tests
5. **Test Edge Cases**: Include tests for error conditions and edge cases
6. **Performance Testing**: Include performance benchmarks for critical paths
7. **Documentation**: Use tests as documentation of expected behavior
8. **Continuous Integration**: Run tests automatically on all changes