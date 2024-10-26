require_relative 'lib/prompt_manager'
require_relative 'lib/prompt_manager/storage/file_system_adapter'

HERE = Pathname.new __dir__

PromptManager::Storage::FileSystemAdapter.config do |config|
  config.prompts_dir        = HERE + 'examples/prompts_dir'
  # config.search_proc      = nil     # default
  # config.prompt_extension = '.txt'  # default
  # config.parms+_extension = '.json' # default
end

PromptManager::Prompt.storage_adapter = PromptManager::Storage::FileSystemAdapter.new

