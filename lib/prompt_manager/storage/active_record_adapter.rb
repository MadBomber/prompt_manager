# prompt_manager/lib/prompt_manager/storage/active_record_adapter.rb

# This class acts as an adapter for interacting with an ActiveRecord model
# to manage storage operations for PromptManager::Prompt instances. It defines
# methods that allow for saving, searching, retrieving by ID, and deleting
# prompts.

class PromptManager::Storage::ActiveRecordAdapter
  
  class << self
    attr_accessor :model, 
                  :prompt_id_column, 
                  :prompt_text_column, 
                  :parameters_column

    def config
      if block_given?
        yield self
        validate_configuration
      else
        raise ArgumentError, "No block given to config"
      end
      
      self
    end


    def validate_configuration
      validate_model
      validate_columns
    end


    def validate_model
      raise ArgumentError, "AR Model not set" unless model
      raise ArgumentError, "AR Model is not an ActiveRecord model" unless model < ActiveRecord::Base
    end


    def validate_columns
      columns = model.column_names # Array of Strings
      [prompt_id_column, prompt_text_column, parameters_column].each do |column|
        raise ArgumentError, "#{column} is not a valid column for model #{model}" unless columns.include?(column.to_s)
      end
    end



    def method_missing(method_name, *args, &block)
      if model.respond_to?(method_name)
        model.send(method_name, *args, &block)
      else
        super
      end
    end


    def respond_to_missing?(method_name, include_private = false)
      model.respond_to?(method_name, include_private) || super
    end
  end
  

  ##############################################
  attr_accessor :record


  # Avoid code littered with self.class prefixes ...
  def model               = self.class.model
  def prompt_id_column    = self.class.prompt_id_column
  def prompt_text_column  = self.class.prompt_text_column
  def parameters_column   = self.class.parameters_column


  def initialize
    self.class.send(:validate_configuration) # send gets around private designations of a method
    @record = model.first
  end


  def get(id:)
    @record = model.find_by(prompt_id_column => id)
    raise ArgumentError, "Prompt not found with id: #{id}" unless @record

    # kludge? testing showed that parameters was being
    # returned as a String.  Did serialization fail or is
    # there something else going on?
    # FIXME: expected the parameters_column to be a HAsh after de-serialization
    parameters = @record[parameters_column]

    if parameters.is_a? String
      parameters = JSON.parse parameters
    end

    {
      id:         id, # same as the prompt_id_column
      text:       @record[prompt_text_column],
      parameters: parameters
    }
  end


  def save(id:, text: "", parameters: {})
    @record = model.find_or_initialize_by(prompt_id_column => id) 

    @record[prompt_text_column] = text
    @record[parameters_column]  = parameters
    @record.save!
  end


  def delete(id:)
    @record = model.find_by(prompt_id_column => id)
    @record&.destroy
  end


  
  def list(*)
    model.all.pluck(prompt_id_column)
  end


  def search(for_what)
    model.where("#{prompt_text_column} LIKE ?", "%#{for_what}%").pluck(prompt_id_column)
  end


  ##############################################
  private


  def method_missing(method_name, *args, &block)
    if @record.respond_to?(method_name)
      model.send(method_name, args.first, &block)
    else
      super
    end
  end


  def respond_to_missing?(method_name, include_private = false)
    model.respond_to?(method_name, include_private) || super
  end
end

