# prompt_manager/lib/prompt_manager/storage/active_record_adapter.rb

require 'active_record'

# TODO: Will need a database.yml file
#       will need to know the column names that coorespond
#       with the things that the Prompt class wants.

class PromptManager::Storage::ActiveRecordAdapter
  attr_reader :model_class

  def initialize(model_class)
    @model_class = model_class
  end


  def prompt_text(prompt_id)
    prompt = find_prompt(prompt_id)
    prompt.text
  end


  def parameter_values(prompt_id)
    prompt = find_prompt(prompt_id)
    JSON.parse(prompt.params, symbolize_names: true)
  end


  def save(prompt_id, prompt_text, parameter_values)
    prompt        = model_class.find_or_initialize_by(id: prompt_id)
    prompt.text   = prompt_text
    prompt.params = parameter_values.to_json
    prompt.save!
  end


  def delete(prompt_id)
    prompt = find_prompt(prompt_id)
    prompt.destroy
  end


  def search(for_what)
    # TODO: search through all prompts. Return an Array of
    #       prompt_id where the text of the prompt contains
    #       for_what is being searched.

    []
  end


  class << self
    def config
      # TODO: establish a connection to the database
      #       maybe define the prompts table and its
      #       columns of interest.
    end
  end

  ###############################################
  private

  def find_prompt(prompt_id)
    model_class.find_by(id: prompt_id) || raise('Prompt not found')
  end
end


__END__

# prompt_manager/lib/prompt_manager/storage/active_record_adapter.rb

require 'active_record'

module PromptManager
  module Storage
    class ActiveRecordAdapter

      # Define models for ActiveRecord
      class Prompt < ActiveRecord::Base
        validates :unique_id, presence: true
        validates :text, presence: true
      end

      class PromptParameter < ActiveRecord::Base
        belongs_to :prompt
        validates :key, presence: true
        serialize :value
      end

      def initialize
        unless ActiveRecord::Base.connected?
          raise ArgumentError, "ActiveRecord is not connected"
        end
      end

      def get(id:)
        prompt = Prompt.find_by(unique_id: id)
        return nil unless prompt

        parameters = prompt.prompt_parameters.index_by(&:key)

        {
          id:         prompt.unique_id,
          text:       prompt.text,
          parameters: parameters.transform_values(&:value)
        }
      end

      def save(id:, text: "", parameters: {})
        prompt = Prompt.find_or_initialize_by(unique_id: id)
        prompt.text = text
        prompt.save!

        parameters.each do |key, value|
          parameter = PromptParameter.find_or_initialize_by(prompt: prompt, key: key)
          parameter.value = value
          parameter.save!
        end
      end

      def delete(id:)
        prompt = Prompt.find_by(unique_id: id)
        return unless prompt
        
        prompt.prompt_parameters.destroy_all
        prompt.destroy
      end

      def search(for_what)
        query = '%' + for_what.downcase + '%'
        Prompt.where('LOWER(text) LIKE ?', query).pluck(:unique_id)
      end

      def list(*)
        Prompt.pluck(:unique_id)
      end

      private

      # This is an example of how the database connection setup could look like, 
      # but it should be handled externally in the actual application setup.
      def self.setup_database_connection
        ActiveRecord::Base.establish_connection(
          adapter: 'sqlite3',
          database: 'prompts.db'
        )
      end
    end
  end
end

# After this, you would need to create a database migration to generate the required tables.
# Additionally, you have to establish an ActiveRecord connection before using this adapter,
# typically in the environment setup of your application.

# Keep in mind you need to create migrations for both the Prompt and PromptParameter models,
# and manage the database schema using ActiveRecord migrations. This adapter assumes that the
# database structure is already in place and follows the schema inferred by the models in the adapter.


