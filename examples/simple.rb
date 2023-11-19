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

PromptManager::Prompt.storage_adapter = 
  PromptManager::Storage::FileSystemAdapter.new(
    prompts_dir: PROMPTS_DIR
  )

# Get a prompt

todo = PromptManager::Prompt.get(id: 'todo')

# This sequence simulates presenting each of the previously
# used values for each keyword to the user to accept or
# edit.

# ap todo.keywords

# This is a new keyword that was added after the current
# todo.json file was created.  Simulate the user setting
# its value.

todo.parameters["[KEYWORD_AKA_TODO]"] = "TODO"

# When the parameter values change, the prompt must 
# must be rebuilt using the build method.

todo.build 


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

