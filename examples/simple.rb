#!/usr/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true
# warn_indent: true
##########################################################
###
##  File: simple.rb
##  Desc: Simple demo of the PromptManager and FileStorageAdapter
##  By:   Dewayne VanHoozer (dvanhoozer@gmail.com)
##
#

require 'prompt_manager'
require 'prompt_manager/storage/file_system_adapter'

require 'amazing_print'
require 'pathname'

HERE        = Pathname.new( __dir__ )
PROMPTS_DIR = HERE + "prompts_dir"


######################################################
# Main

at_exit do
  puts
  puts "Done."
  puts
end

# Configure the Storage Adapter to use
PromptManager::Storage::FileSystemAdapter.config do |config|
  config.prompts_dir        = PROMPTS_DIR
  # config.search_proc      = nil     # default
  # config.prompt_extension = '.txt'  # default
  # config.parms+_extension = '.json' # default
end

PromptManager::Prompt.storage_adapter = PromptManager::Storage::FileSystemAdapter.new

# Get a prompt
# Note: The 'get' method returns a Hash, not a Prompt object
# Use 'find' instead to get a Prompt object with methods

todo = PromptManager::Prompt.find(id: 'todo')

# This sequence simulates presenting each of the previously
# used values for each keyword to the user to accept or
# edit.

# ap todo.keywords

# This is a new keyword that was added after the current
# todo.json file was created.  Simulate the user setting
# its value.

todo.parameters["[KEYWORD_AKA_TODO]"] = "TODO"

# When the parameter values change, the prompt must
# be saved to persist the changes
todo.save


puts <<~EOS
  
  Raw Text from Prompt File
  includes all lines
  =========================
EOS

puts todo.text


puts <<~EOS
  
  Last Set of Parameters Used
  Includes those recently added
  =============================
EOS

ap todo.parameters


puts <<~EOS
  
  Prompt Ready to Send to gen-AI
  ==============================
EOS

puts todo.to_s

puts <<~EOS

  When using the FileSystemAdapter for prompt storage you can have within 
  the prompts_dir you can have many sub-directories. These sub-directories 
  act like categories.  The prompt ID is composed for the sub-directory name, 
  a "/" character and then the normal prompt ID.  For example "toy/8-ball"

EOS

magic = PromptManager::Prompt.find(id: 'toy/8-ball')

puts "The magic PROMPT is:"
puts magic
puts
puts "Remember if you want to see the full text of the prompt file:"
puts magic.text

puts "="*64

puts <<~EOS

  The FileSystemAdapter also adds two new class methods to the Prompt class:

    list - provides an Array of prompt IDs
    path(prompt_id) - Returns a Pathname object to the prompt file

EOS

puts "List of prompts available"
puts "========================="

puts PromptManager::Prompt.list

puts <<~EOS

  And the path to the "toy/8-ball" prompt file is:

  #{PromptManager::Prompt.path('toy/8-ball')}

  Use "your_prompt.path" for when you want to do something with the
  the prompt file like send it to a text editor.

  Your can also use the class method if you supply a prompt_id
  like this:

EOS

puts PromptManager::Prompt.path('toy/8-ball')

puts

puts "Default Search for Prompts"
puts "=========================="

print "Search Proc Class: "
puts PromptManager::Prompt.storage_adapter.search_proc.class

search_term = "txt"  # some comment lines show the file name example: todo.txt

puts "Search for '#{search_term}' ..."

prompt_ids = PromptManager::Prompt.search search_term

# NOTE: prompt+ids is an Array of prompt IDs even if there is only one entry.
#       or and empty array if there are no prompts have the search term.

puts "Found: #{prompt_ids}"

