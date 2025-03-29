# prompt_manager/lib/prompt_manager/storage/active_record_adapter.rb

# This class acts as an adapter for interacting with an ActiveRecord model
require 'active_record'
# to manage storage operations for PromptManager::Prompt instances. It defines
# methods that allow for saving, searching, retrieving by ID, and deleting
# prompts.
#
# To use this adapter, you must configure it with an ActiveRecord model and
# the column names for ID, text content, and parameters. The adapter will
# handle serialization and deserialization of parameters.
#
# This adapter is used by PromptManager::Prompt as its storage backend, enabling CRUD operations on persistent prompt data.

class PromptManager::Storage::ActiveRecordAdapter
  
  class << self
    # Configure the ActiveRecord model and column mappings
    attr_accessor :model,
                  :id_column,
                  :text_column,
                  :parameters_column

    # Configure the adapter with the required settings
    # Must be called with a block before using the adapter
    def config
      if block_given?
        yield self
        validate_configuration
      else
        raise ArgumentError, "No block given to config"
      end
      
      self
    end

    # Validate that all required configuration is present and valid
    def validate_configuration
      validate_model
      validate_columns
    end

    # Ensure the provided model is a valid ActiveRecord model
    def validate_model
      raise ArgumentError, "AR Model not set" unless model
      raise ArgumentError, "AR Model is not an ActiveRecord model" unless model < ActiveRecord::Base
    end

    # Verify that all required columns exist in the model
    def validate_columns
      columns = model.column_names # Array of Strings
      [id_column, text_column, parameters_column].each do |column|
        raise ArgumentError, "#{column} is not a valid column for model #{model}" unless columns.include?(column.to_s)
      end
    end

    # Delegate unknown methods to the ActiveRecord model
    def method_missing(method_name, *args, &block)
      if model.respond_to?(method_name)
        model.send(method_name, *args, &block)
      else
        super
      end
    end

    # Support respond_to? for delegated methods
    def respond_to_missing?(method_name, include_private = false)
      model.respond_to?(method_name, include_private) || super
    end
  end
  

  ##############################################
  # The ActiveRecord object representing the current prompt
  attr_accessor :record

  # Accessor methods to avoid repeated self.class prefixes
  def model             = self.class.model
  def id_column         = self.class.id_column
  def text_column       = self.class.text_column
  def parameters_column = self.class.parameters_column

  # Initialize the adapter and validate configuration
  def initialize
    self.class.send(:validate_configuration) # send gets around private designations of a method
    @record = model.first
  end

  # Retrieve a prompt by its ID
  # Returns a hash with id, text, and parameters
  def get(id:)
    @record = model.find_by(id_column => id)
    raise ArgumentError, "Prompt not found with id: #{id}" unless @record

    # Handle case where parameters might be stored as a JSON string
    # instead of a native Hash
    parameters = @record[parameters_column]

    if parameters.is_a? String
      parameters = JSON.parse parameters
    end

    {
      id:         id,
      text:       @record[text_column],
      parameters: parameters
    }
  end

  # Save a prompt with the given ID, text, and parameters
  # Creates a new record if one doesn't exist, otherwise updates existing record
  def save(id:, text: "", parameters: {})
    @record = model.find_or_initialize_by(id_column => id) 

    @record[text_column] = text
    @record[parameters_column] = parameters
    @record.save!
  end

  # Delete a prompt with the given ID
  def delete(id:)
    @record = model.find_by(id_column => id)
    @record&.destroy
  end

  # Return an array of all prompt IDs
  def list(*)
    model.all.pluck(id_column)
  end

  # Search for prompts containing the given text
  # Returns an array of matching prompt IDs
  def search(for_what)
    model.where("#{text_column} LIKE ?", "%#{for_what}%").pluck(id_column)
  end

  ##############################################
  private

  # Delegate unknown methods to the current record
  def method_missing(method_name, *args, &block)
    if @record && @record.respond_to?(method_name)
      @record.send(method_name, *args, &block)
    elsif model.respond_to?(method_name)
      model.send(method_name, *args, &block)
    else
      super
    end
  end

  # Support respond_to? for delegated methods
  def respond_to_missing?(method_name, include_private = false)
    (model.respond_to?(method_name, include_private) ||
     (@record && @record.respond_to?(method_name, include_private)) ||
     super)
  end
end
