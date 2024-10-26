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
PromptManager::Prompt.parameter_regex =  /\{[A-Za-z _|]+\}/ 

# Retrieve a prompt
prompt = PromptManager::Prompt.get(id: 'directive_example')

# Shows prompt without comments or directives
# It still has its parameter placeholders
puts prompt
concept_break

puts "Directives in the prompt:"
ap prompt.directives

puts "Processing directives ..."
prompt.directives.each do |entry|
  if MyDirectives.respond_to? entry.first.to_sym
    ruby = "MyDirectives.#{entry.first}(#{entry.last.gsub(' ', ',')})"
    eval "#{ruby}"
  else
    puts "ERROR: there is no method: #{entry.first}"
  end
end

concept_break



puts "Parameters in the prompt:"
ap prompt.parameters
puts "-"*16

puts "keywords:"
ap prompt.keywords
concept_break

prompt.parameters['{language}'] << 'French'

puts "After Substitution"
puts prompt

