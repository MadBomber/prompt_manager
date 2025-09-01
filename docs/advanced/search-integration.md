# Search Integration

PromptManager provides powerful search capabilities to find, filter, and organize prompts across your entire prompt library.

## Basic Search

### Simple Text Search

```ruby
# Search by prompt content
results = PromptManager.search("customer service")
results.each do |prompt_id|
  puts "Found: #{prompt_id}"
end

# Search with options
results = PromptManager.search(
  query: "email template",
  limit: 10,
  include_content: true
)

results.each do |result|
  puts "ID: #{result[:id]}"
  puts "Content: #{result[:content][0..100]}..."
end
```

### Search by Metadata

```ruby
# Search by prompt ID pattern
email_prompts = PromptManager.search(id_pattern: /email/)

# Search by file path (FileSystem adapter)
marketing_prompts = PromptManager.search(path_pattern: /marketing/)

# Search by tags (if using metadata)
customer_service = PromptManager.search(tags: ['customer-service', 'support'])
```

## Advanced Search Features

### Full-Text Search with Elasticsearch

```ruby
# config/initializers/prompt_manager.rb
PromptManager.configure do |config|
  config.search_backend = PromptManager::Search::ElasticsearchBackend.new(
    host: ENV['ELASTICSEARCH_URL'],
    index: 'prompt_manager_prompts'
  )
end

class PromptManager::Search::ElasticsearchBackend
  def initialize(host:, index:)
    @client = Elasticsearch::Client.new(hosts: host)
    @index = index
    setup_index
  end
  
  def search(query, options = {})
    search_body = build_search_query(query, options)
    
    response = @client.search(
      index: @index,
      body: search_body
    )
    
    parse_search_results(response)
  end
  
  def index_prompt(prompt_id, content, metadata = {})
    document = {
      id: prompt_id,
      content: content,
      metadata: metadata,
      indexed_at: Time.current.iso8601,
      parameters: extract_parameters(content),
      directives: extract_directives(content)
    }
    
    @client.index(
      index: @index,
      id: prompt_id,
      body: document
    )
  end
  
  private
  
  def build_search_query(query, options)
    {
      query: {
        bool: {
          should: [
            {
              match: {
                content: {
                  query: query,
                  boost: 2.0
                }
              }
            },
            {
              match: {
                id: {
                  query: query,
                  boost: 1.5
                }
              }
            },
            {
              nested: {
                path: 'metadata',
                query: {
                  match: {
                    'metadata.description': query
                  }
                }
              }
            }
          ],
          filter: build_filters(options)
        }
      },
      highlight: {
        fields: {
          content: {},
          id: {}
        }
      },
      size: options[:limit] || 20,
      from: options[:offset] || 0
    }
  end
end
```

### Faceted Search

```ruby
search_results = PromptManager.search(
  query: "email",
  facets: {
    tags: {},
    category: {},
    last_modified: {
      ranges: [
        { to: "now-1d", label: "Last 24 hours" },
        { from: "now-7d", to: "now-1d", label: "Last week" },
        { from: "now-30d", to: "now-7d", label: "Last month" }
      ]
    }
  }
)

puts "Results: #{search_results[:total]}"
puts "Facets:"
search_results[:facets].each do |facet_name, facet_data|
  puts "  #{facet_name}:"
  facet_data[:buckets].each do |bucket|
    puts "    #{bucket[:label]}: #{bucket[:count]}"
  end
end
```

### Semantic Search with Vector Embeddings

```ruby
class PromptManager::Search::VectorBackend
  def initialize(embedding_model: 'text-embedding-ada-002')
    @openai = OpenAI::Client.new
    @embedding_model = embedding_model
    @vector_db = Pinecone::Client.new
  end
  
  def index_prompt(prompt_id, content, metadata = {})
    # Generate embedding
    embedding_response = @openai.embeddings(
      parameters: {
        model: @embedding_model,
        input: content
      }
    )
    
    embedding = embedding_response['data'][0]['embedding']
    
    # Store in vector database
    @vector_db.upsert(
      namespace: 'prompts',
      vectors: [{
        id: prompt_id,
        values: embedding,
        metadata: {
          content: content,
          **metadata
        }
      }]
    )
  end
  
  def semantic_search(query, limit: 10, similarity_threshold: 0.8)
    # Generate query embedding
    query_embedding = @openai.embeddings(
      parameters: {
        model: @embedding_model,
        input: query
      }
    )['data'][0]['embedding']
    
    # Search for similar vectors
    results = @vector_db.query(
      namespace: 'prompts',
      vector: query_embedding,
      top_k: limit,
      include_metadata: true
    )
    
    # Filter by similarity threshold
    results['matches'].select do |match|
      match['score'] >= similarity_threshold
    end
  end
end

# Usage
PromptManager.configure do |config|
  config.search_backend = PromptManager::Search::VectorBackend.new
end

# Find semantically similar prompts
similar_prompts = PromptManager.semantic_search(
  "greeting message for new customers",
  limit: 5
)

similar_prompts.each do |result|
  puts "#{result['id']} (similarity: #{result['score']})"
  puts result['metadata']['content'][0..100]
  puts "---"
end
```

## Search Integration Patterns

### Auto-completion and Suggestions

```ruby
class PromptSearchController < ApplicationController
  def autocomplete
    query = params[:q]
    suggestions = PromptManager.search(
      query: query,
      type: :autocomplete,
      limit: 10
    )
    
    render json: {
      suggestions: suggestions.map do |result|
        {
          id: result[:id],
          title: result[:title] || result[:id].humanize,
          description: result[:content][0..100],
          category: result[:metadata][:category]
        }
      end
    }
  end
  
  def search
    results = PromptManager.search(
      query: params[:q],
      filters: search_filters,
      facets: search_facets,
      page: params[:page] || 1,
      per_page: 20
    )
    
    render json: {
      results: results[:items],
      total: results[:total],
      facets: results[:facets],
      pagination: {
        page: params[:page]&.to_i || 1,
        total_pages: (results[:total] / 20.0).ceil
      }
    }
  end
  
  private
  
  def search_filters
    filters = {}
    filters[:category] = params[:category] if params[:category].present?
    filters[:tags] = params[:tags].split(',') if params[:tags].present?
    filters[:date_range] = params[:date_range] if params[:date_range].present?
    filters
  end
end
```

### Search Analytics

```ruby
class SearchAnalytics
  def self.track_search(query, user_id, results_count)
    SearchLog.create!(
      query: query,
      user_id: user_id,
      results_count: results_count,
      searched_at: Time.current
    )
  end
  
  def self.popular_searches(limit: 10)
    SearchLog
      .where('searched_at > ?', 30.days.ago)
      .group(:query)
      .order('count_all DESC')
      .limit(limit)
      .count
  end
  
  def self.search_trends
    SearchLog
      .where('searched_at > ?', 7.days.ago)
      .group('DATE(searched_at)')
      .count
  end
  
  def self.no_results_queries
    SearchLog
      .where(results_count: 0)
      .where('searched_at > ?', 7.days.ago)
      .group(:query)
      .order('count_all DESC')
      .limit(20)
      .count
  end
end

# Usage in search
results = PromptManager.search(params[:q])
SearchAnalytics.track_search(params[:q], current_user.id, results.count)
```

### Search Result Ranking

```ruby
class PromptRankingService
  RANKING_FACTORS = {
    exact_match: 3.0,
    title_match: 2.0,
    content_relevance: 1.0,
    recency: 0.5,
    usage_frequency: 1.5,
    user_preference: 2.0
  }.freeze
  
  def self.rank_results(results, query, user_context = {})
    scored_results = results.map do |result|
      score = calculate_score(result, query, user_context)
      result.merge(relevance_score: score)
    end
    
    scored_results.sort_by { |r| -r[:relevance_score] }
  end
  
  private
  
  def self.calculate_score(result, query, user_context)
    score = 0.0
    
    # Exact match bonus
    if result[:id].downcase.include?(query.downcase)
      score += RANKING_FACTORS[:exact_match]
    end
    
    # Content relevance
    content_matches = result[:content].downcase.scan(query.downcase).size
    score += content_matches * RANKING_FACTORS[:content_relevance]
    
    # Recency bonus
    days_old = (Time.current - result[:updated_at]).to_f / 1.day
    recency_factor = [1.0 - (days_old / 365.0), 0.0].max
    score += recency_factor * RANKING_FACTORS[:recency]
    
    # Usage frequency
    usage_count = PromptUsageLog.where(prompt_id: result[:id])
                                .where('used_at > ?', 30.days.ago)
                                .count
    score += Math.log(usage_count + 1) * RANKING_FACTORS[:usage_frequency]
    
    # User preference (based on past usage)
    if user_context[:user_id]
      user_usage = PromptUsageLog.where(
        prompt_id: result[:id],
        user_id: user_context[:user_id]
      ).count
      score += Math.log(user_usage + 1) * RANKING_FACTORS[:user_preference]
    end
    
    score
  end
end
```

## Search UI Components

### React Search Component

```jsx
// components/PromptSearch.jsx
import React, { useState, useEffect, useMemo } from 'react';
import { debounce } from 'lodash';

const PromptSearch = () => {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [facets, setFacets] = useState({});
  const [selectedFilters, setSelectedFilters] = useState({});
  const [loading, setLoading] = useState(false);

  const debouncedSearch = useMemo(
    () => debounce(async (searchQuery, filters) => {
      setLoading(true);
      try {
        const response = await fetch('/api/prompts/search', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            query: searchQuery,
            filters: filters
          }),
        });
        
        const data = await response.json();
        setResults(data.results);
        setFacets(data.facets);
      } catch (error) {
        console.error('Search error:', error);
      } finally {
        setLoading(false);
      }
    }, 300),
    []
  );

  useEffect(() => {
    if (query.length > 2) {
      debouncedSearch(query, selectedFilters);
    } else {
      setResults([]);
    }
  }, [query, selectedFilters, debouncedSearch]);

  return (
    <div className="prompt-search">
      <div className="search-input">
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search prompts..."
          className="search-field"
        />
        {loading && <div className="search-spinner">Loading...</div>}
      </div>

      <div className="search-content">
        <div className="search-filters">
          {Object.entries(facets).map(([facetName, facetData]) => (
            <div key={facetName} className="facet-group">
              <h4>{facetName.charAt(0).toUpperCase() + facetName.slice(1)}</h4>
              {facetData.buckets.map(bucket => (
                <label key={bucket.key} className="facet-option">
                  <input
                    type="checkbox"
                    checked={selectedFilters[facetName]?.includes(bucket.key) || false}
                    onChange={(e) => handleFilterChange(facetName, bucket.key, e.target.checked)}
                  />
                  {bucket.label} ({bucket.count})
                </label>
              ))}
            </div>
          ))}
        </div>

        <div className="search-results">
          {results.map(result => (
            <div key={result.id} className="search-result">
              <h3 className="result-title">{result.title || result.id}</h3>
              <p className="result-content">{result.snippet}</p>
              <div className="result-metadata">
                <span className="result-category">{result.category}</span>
                <span className="result-score">Score: {result.relevance_score?.toFixed(2)}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default PromptSearch;
```

### Search API Implementation

```ruby
class Api::PromptsController < ApplicationController
  def search
    search_params = params.require(:search).permit(
      :query, :page, :per_page,
      filters: {},
      facets: []
    )
    
    results = PromptManager.search(
      query: search_params[:query],
      filters: search_params[:filters] || {},
      facets: search_params[:facets] || [],
      page: search_params[:page]&.to_i || 1,
      per_page: [search_params[:per_page]&.to_i || 20, 100].min
    )
    
    # Apply custom ranking
    ranked_results = PromptRankingService.rank_results(
      results[:items],
      search_params[:query],
      user_context: { user_id: current_user&.id }
    )
    
    render json: {
      results: ranked_results,
      total: results[:total],
      facets: results[:facets],
      query: search_params[:query]
    }
  end
  
  def suggestions
    query = params[:q]
    
    suggestions = PromptManager.search(
      query: query,
      type: :suggestions,
      limit: 8
    )
    
    render json: {
      suggestions: suggestions.map do |s|
        {
          text: s[:id].humanize,
          value: s[:id],
          category: s[:metadata][:category]
        }
      end
    }
  end
end
```

## Performance Optimization

### Search Indexing Strategy

```ruby
class PromptIndexer
  def self.reindex_all
    total_prompts = PromptManager.list.count
    
    PromptManager.list.each_with_index do |prompt_id, index|
      begin
        prompt = PromptManager::Prompt.new(id: prompt_id)
        content = prompt.content
        metadata = extract_metadata(prompt)
        
        PromptManager.search_backend.index_prompt(
          prompt_id,
          content,
          metadata
        )
        
        puts "Indexed #{index + 1}/#{total_prompts}: #{prompt_id}"
      rescue => e
        Rails.logger.error "Failed to index #{prompt_id}: #{e.message}"
      end
    end
  end
  
  def self.incremental_index
    # Index only recently modified prompts
    recently_modified = PromptManager.list.select do |prompt_id|
      prompt = PromptManager::Prompt.new(id: prompt_id)
      last_modified = File.mtime(prompt.file_path) rescue Time.at(0)
      last_indexed = IndexLog.where(prompt_id: prompt_id).maximum(:indexed_at) || Time.at(0)
      
      last_modified > last_indexed
    end
    
    recently_modified.each do |prompt_id|
      index_single_prompt(prompt_id)
    end
  end
end

# Schedule regular reindexing
class PromptReindexJob < ApplicationJob
  def perform
    PromptIndexer.incremental_index
  end
end

# Run every hour
# schedule.rb or similar
every 1.hour do
  PromptReindexJob.perform_later
end
```

## Best Practices

1. **Index Management**: Keep search indexes up to date with prompt changes
2. **Query Optimization**: Use proper filters and pagination to improve performance
3. **Result Ranking**: Implement relevance scoring based on user behavior
4. **Analytics**: Track search patterns to improve the search experience
5. **Faceted Navigation**: Provide filters to help users narrow down results
6. **Error Handling**: Gracefully handle search backend failures
7. **Caching**: Cache frequent searches and autocomplete suggestions
8. **Security**: Ensure search queries are properly sanitized and authorized