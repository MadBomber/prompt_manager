# prompt_manager/lib/prompt_manager/storage.rb

# The Storage module provides a namespace for different storage adapters
# that handle persistence of prompts. Each adapter implements a common
# interface for saving, retrieving, searching, and deleting prompts.
#
# Available adapters:
# - FileSystemAdapter: Stores prompts in text files on the local filesystem
# - ActiveRecordAdapter: Stores prompts in a database using ActiveRecord
#
# To use an adapter, configure it before using PromptManager::
#
# Example with FileSystemAdapter:
#   PromptManager::Storage::FileSystemAdapter.config do |config|
#     config.prompts_dir = Pathname.new('/path/to/prompts')
#   end
#   PromptManager::Prompt.storage_adapter = PromptManager::Storage::FileSystemAdapter.new
#
# Example with ActiveRecordAdapter:
#   PromptManager::Storage::ActiveRecordAdapter.config do |config|
#     config.model = MyPromptModel
#     config.id_column = :prompt_id
#     config.text_column = :content
#     config.parameters_column = :params
#   end
#   PromptManager::Prompt.storage_adapter = PromptManager::Storage::ActiveRecordAdapter.new
module PromptManager
  # The Storage module provides adapters for different storage backends.
  # Each adapter implements a common interface for managing prompts.
  module Storage
  end
end
