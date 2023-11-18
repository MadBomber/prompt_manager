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




