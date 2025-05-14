#!/usr/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true
# warn_indent: true
##########################################################
###
##  File: directives.rb
##  Desc: Demo of the PromptManager and FileStorageAdapter
##  By:   Dewayne VanHoozer (dvanhoozer@gmail.com)
##
#

param1 = "param_one"
param2 = "param_two"


class MyDirectives
  def self.good_directive(*args)
    puts "inside #{__method__} with these parameters:"
    puts args.join(",\n")
  end
end

def concept_break = print "\n------------------------\n\n\n"

require_relative '../lib/prompt_manager'
require_relative '../lib/prompt_manager/storage/file_system_adapter'

require 'amazing_print'
require 'pathname'

require 'debug_me'
include DebugMe

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

# Use {parameter name} brackets to define a parameter
# Note: must include capturing parentheses to make scan return arrays
PromptManager::Prompt.parameter_regex =  /(\{[A-Za-z _|]+\})/ 

# Retrieve a prompt
# Note: The 'get' method returns a Hash, not a Prompt object
# Use 'find' instead to get a Prompt object with methods
prompt = PromptManager::Prompt.find(id: 'directive_example')

# Shows prompt without comments or directives
# It still has its parameter placeholders
puts prompt
concept_break

puts "Directives are processed automatically when you call to_s on a prompt"
puts "The DirectiveProcessor class handles directives like //include"
puts "You don't need to process them manually"

puts "Custom directive processing can be done by creating a custom DirectiveProcessor"
puts "and setting it when creating a Prompt instance:"

concept_break



puts "Parameters in the prompt:"
ap prompt.parameters
puts "-"*16

# Extract parameters from the prompt text using the parameter_regex
puts "Parameters identified in the prompt text:"
# With a capturing group, scan returns an array of arrays, so we need to flatten
prompt_params = prompt.text.scan(PromptManager::Prompt.parameter_regex).flatten
ap prompt_params
concept_break

# Set a parameter value (should be a string, not appending to an array)
prompt.parameters['{language}'] = 'French'

puts "After Substitution"
puts prompt

# Save the updated parameters
prompt.save

