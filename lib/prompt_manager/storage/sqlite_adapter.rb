# prompt_manager/lib/prompt_manager/storage/sqlite_adapter.rb

require 'json'
require 'sqlite3'

class PromptManager::Storage::SqliteAdapter
  def initialize(db_path = 'prompts.db')
    @db = SQLite3::Database.new(db_path)
    create_tables
  end

  def save_prompt(prompt_id, text, params)
    @db.execute("INSERT INTO prompts (id, text, params) VALUES (?, ?, ?)",
                [prompt_id, text, params.to_json])
  end

  def prompt_text(prompt_id)
    result = @db.get_first_value("SELECT text FROM prompts WHERE id = ?", [prompt_id])
    raise 'Prompt not found' if result.nil?
    result
  end

  def parameter_values(prompt_id)
    json_content = @db.get_first_value("SELECT params FROM prompts WHERE id = ?", [prompt_id])
    raise 'Parameters not found' if json_content.nil?
    JSON.parse(json_content, symbolize_names: true)
  end

  def save(prompt_id, prompt_text, parameter_values)
    @db.execute(
      'REPLACE INTO prompts (id, text, params) VALUES (?, ?, ?)',
      [prompt_id, prompt_text, parameter_values.to_json]
    )
  end

  def delete(prompt_id)
    @db.execute('DELETE FROM prompts WHERE id = ?', [prompt_id])
  end


  def search(for_what)
    # TODO: search through all prompts. Return an Array of
    #       prompt_id where the text of the prompt contains
    #       for_what is being searched.

    []
  end

  ###################################################
  private

  def create_tables
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS prompts (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        params TEXT NOT NULL
      );
    SQL
  end
end


__END__


require 'sequel'
require 'pathname'
require 'json'

module PromptManager
  module Storage
    class SqliteAdapter
      DEFAULT_DB_FILE = 'prompts.sqlite3'.freeze

      class << self
        attr_accessor :db_file, :db

        def config
          if block_given?
            yield self
          else
            raise ArgumentError, 'No block given to config'
          end

          self.db = Sequel.sqlite(db_file || DEFAULT_DB_FILE) # Use provided db_file or default
          create_tables unless db.table_exists?(:prompts)
        end

        # Define the necessary tables within the SQLite database if they don't exist
        def create_tables
          db.create_table :prompts do
            primary_key :id
            String :prompt_id, unique: true, null: false
            Text :text
            Json :parameters

            index :prompt_id
          end
        end
      end

      def initialize
        @db = self.class.db
      end

      def get(id:)
        validate_id(id)
        result = @db[:prompts].where(prompt_id: id).first 
        raise ArgumentError, 'Prompt not found' unless result

        {
          id:         result[:prompt_id],
          text:       result[:text],
          parameters: result[:parameters]
        }
      end

      def save(id:, text: '', parameters: {})
        validate_id(id)
        rec = @db[:prompts].where(prompt_id: id).first
        if rec
          @db[:prompts].where(prompt_id: id).update(text: text, parameters: Sequel.pg_json(parameters))
        else
          @db[:prompts].insert(prompt_id: id, text: text, parameters: Sequel.pg_json(parameters))
        end
      end

      def delete(id:)
        validate_id(id)
        @db[:prompts].where(prompt_id: id).delete
      end

      # Return an Array of prompt IDs
      def list()
        @db[:prompts].select_map(:prompt_id)
      end

      def search(for_what)
        search_term = for_what.downcase
        @db[:prompts].where(Sequel.ilike(:text, "%#{search_term}%")).select_map(:prompt_id)
      end

      private

      # Validate that the ID contains good characters.
      def validate_id(id)
        raise ArgumentError, "Invalid ID format id: #{id}" unless id =~ /^[a-zA-Z0-9\-\/_]+$/
      end
    end
  end
end




