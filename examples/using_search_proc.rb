#!/usr/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true
# warn_indent: true
##########################################################
###
##  File: using_search_proc.rb
##  Desc: Simple demo of the PromptManager and FileStorageAdapter
##  By:   Dewayne VanHoozer (dvanhoozer@gmail.com)
##
#

require 'debug_me'
include DebugMe

require 'prompt_manager'
require 'prompt_manager/storage/file_system_adapter'

require 'amazing_print'
require 'pathname'

HERE          = Pathname.new( __dir__ )
PROMPTS_DIR   = HERE + "prompts_dir"
SEARCH_SCRIPT = HERE + 'rgfzf'  # a bash script using rg and fzf

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
  config.search_proc        = ->(q) {`#{SEARCH_SCRIPT} #{q} #{PROMPTS_DIR}`}     # default
  # config.prompt_extension = '.txt'  # default
  # config.parms+_extension = '.json' # default
end

PromptManager::Prompt.storage_adapter = PromptManager::Storage::FileSystemAdapter.new



puts "Using Custom Search Proc"
puts "========================"

print "Search Proc Class: "
puts PromptManager::Prompt.storage_adapter.search_proc.class

search_term = "txt"  # some comment lines show the file name example: todo.txt

puts "Search for '#{search_term}' ..."

prompt_id = PromptManager::Prompt.search search_term

# NOTE: the search proc uses fzf as a selection tool.  In this
#       case only one selected prompt ID that matches the search
#       term will be returned.

puts "Found: '#{prompt_id}' which is a #{prompt_id.class}. empty? #{prompt_id.empty?}"

puts <<~EOS
  
  When the rgfzf bash script does not find a prompt ID or if the 
  ESC key is pressed, the prompt ID that is returned will be an empty String.

EOS

