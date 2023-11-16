#!/usr/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true
# warn_indent: true
##########################################################
###
##  File: aip.rb
##  Desc: Use generative AI with saved parameterized prompts
##  By:   Dewayne VanHoozer (dvanhoozer@gmail.com)
##
##  This program makes use of the gem word_wrap's
##  CLI tool: ww
#


=begin

brew install fzf mods the_silver_searcher

fzf                  Command-line fuzzy finder written in Go
                     |__ https://github.com/junegunn/fzf

mods                 AI on the command-line
                     |__ https://github.com/charmbracelet/mods

the_silver_searcher  Code-search similar to ack
                     |__ https://github.com/ggreer/the_silver_searcher

Program Summary

The program is a Ruby script that integrates with the `mods` CLI tool, which is built on a GPT-based generative AI model. This script is designed to make use of generative AI through a set of saved, parameterized prompts. Users can easily interact with the following features:

- **Prompt Selection**: Users have the ability to choose a prompt from a curated list. This selection process is streamlined by allowing users to search and filter prompts using keywords.

- **Prompt Editing**: There is functionality for a user to modify the text of an existing prompt, tailoring it to better meet their specific needs.

- **File Input**: The script can read in data from input files, providing the necessary context or information required for the AI to generate relevant content.

- **AI Integration**: Utilizing the `mods` GPT-based CLI tool, the script takes the chosen edited prompt to guide the AI in generating its output.

- **Output Management**: After the generative process, the resulting output is saved to a designated file, ensuring that the user has a record of the AI's creations.

- **Logging**: For tracking and accountability, the program records the details of each session, including the prompt used, the AI-generated output, and the precise timestamp when the generation occurred.

This robust tool is excellent for users who wish to harness the power of generative AI for creating content, with an efficient and user-friendly system for managing the creation process.

=end

#
# TODO: I think this script has reached the point where
#       it is ready to become a proper gem.
#

require 'pathname'
HOME = Pathname.new( ENV['HOME'] )


MODS_MODEL      = ENV['MODS_MODEL'] || 'gpt-4-1106-preview'

AI_CLI_PROGRAM  = "mods"
ai_default_opts = "-m #{MODS_MODEL} --no-limit -f"
ai_options      = ai_default_opts.dup

extra_inx       = ARGV.index('--')

if extra_inx
  ai_options += " " + ARGV[extra_inx+1..].join(' ')
  ARGV.pop(ARGV.size - extra_inx)
end

AI_COMMAND        = "#{AI_CLI_PROGRAM} #{ai_options} "
EDITOR            = ENV['EDITOR']
PROMPT_DIR        = HOME + ".prompts"
PROMPT_LOG        = PROMPT_DIR + "_prompts.log"
PROMPT_EXTNAME    = ".txt"
DEFAULTS_EXTNAME  = ".json"
# SEARCH_COMMAND    = "ag -l"
KEYWORD_REGEX     = /(\[[A-Z _|]+\])/

AVAILABLE_PROMPTS = PROMPT_DIR
                      .children
                      .select{|c| PROMPT_EXTNAME == c.extname}
                      .map{|c| c.basename.to_s.split('.')[0]}

AVAILABLE_PROMPTS_HELP  = AVAILABLE_PROMPTS
                            .map{|c| "  * " + c}
                            .join("\n")

require 'amazing_print'
require 'json'
require 'readline'    # TODO: or reline ??
require 'word_wrap'
require 'word_wrap/core_ext'


require 'debug_me'
include DebugMe

require 'cli_helper'
include CliHelper

configatron.version = '1.1.0'

AI_CLI_PROGRAM_HELP = `#{AI_CLI_PROGRAM} --help`

HELP = <<EOHELP
AI CLI Program
==============

The AI cli program being used is: #{AI_CLI_PROGRAM}

The defaul options to #{AI_CLI_PROGRAM} are:
  "#{ai_default_opts}"

You can pass additional CLI options to #{AI_CLI_PROGRAM} like this:
  "#{my_name} my options -- options for #{AI_CLI_PROGRAM}"

#{AI_CLI_PROGRAM_HELP}

EOHELP

cli_helper("Use generative AI with saved parameterized prompts") do |o|

  o.string  '-p', '--prompt', 'The prompt name',        default: ""
  o.bool    '-e', '--edit',   'Edit the prompt text',   default: false
  o.bool    '-f', '--fuzzy',   'Allow fuzzy matching',  default: false
  o.path    '-o', '--output', 'The output file',        default: Pathname.pwd + "temp.md"
end


AG_COMMAND        = "ag --file-search-regex '\.txt$' e"
CD_COMMAND        = "cd #{PROMPT_DIR}"
FIND_COMMAND      = "find . -name '*.txt'"

FZF_OPTIONS       = [
  "--tabstop=2",  # 2 soaces for a tab
  "--header='Prompt contents below'",
  "--header-first",
  "--prompt='Search term: '",
  '--delimiter :',
  "--preview 'ww {1}'",              # ww comes from the word_wrap gem
  "--preview-window=down:50%:wrap"
].join(' ')

FZF_OPTIONS += "--exact" unless fuzzy?

FZF_COMMAND       = "#{CD_COMMAND} ; #{FIND_COMMAND} | fzf #{FZF_OPTIONS}"
AG_FZF_COMMAND    = "#{CD_COMMAND} ; #{AG_COMMAND}   | fzf #{FZF_OPTIONS}"

# use `ag` ti build a list of text lines from each prompt
# use `fzf` to search through that list to select a prompt file

def ag_fzf = `#{AG_FZF_COMMAND}`.split(':')&.first&.strip&.gsub('.txt','')


configatron.input_files = get_pathnames_from( configatron.arguments, %w[.rb .txt .md])


# TODO: Make the use of the "-p" flag optional.
#       I find myself many times forgetting to use it
#       and this program rejecting it because
#       "the file does not exist" thinging that it
#       was an input file file rather than a prompt
#       name.

if configatron.prompt.empty?
  configatron.prompt  = ag_fzf
end

unless edit?
  if configatron.prompt.nil? || configatron.prompt.empty?
    error "No prompt provided"
  end
end

abort_if_errors

configatron.prompt_path   = PROMPT_DIR + (configatron.prompt + PROMPT_EXTNAME)
configatron.defaults_path = PROMPT_DIR + (configatron.prompt + DEFAULTS_EXTNAME)

if  !configatron.prompt_path.exist? && !edit?
  error "This prompt does not exist: #{configatron.prompt}\n"
end

configatron.prompt_path   = PROMPT_DIR + (configatron.prompt + PROMPT_EXTNAME)
configatron.defaults_path = PROMPT_DIR + (configatron.prompt + DEFAULTS_EXTNAME)

abort_if_errors

if edit?
  unless configatron.prompt_path.exist?
    configatron.prompt_path.write <<~PROMPT
      # #{configatron.prompt_path.relative_path_from(HOME)}
      # DESC: 

    PROMPT
  end

  `#{EDITOR} #{configatron.prompt_path}`
end

######################################################
# Local methods

def extract_raw_prompt
  array_of_strings = ignore_after_end
  print_header_comment(array_of_strings)

  array_of_strings.reject do |a_line|
                    a_line.chomp.strip.start_with?('#')
                  end
                  .join("\n")
end


def ignore_after_end
  array_of_strings  = configatron.prompt_path.readlines
                        .map{|a_line| a_line.chomp.strip}

  x = array_of_strings.index("__END__")

  unless x.nil?
    array_of_strings = array_of_strings[..x-1]
  end

  array_of_strings
end


def print_header_comment(array_of_strings)
  print "\n\n" if verbose?

  x = 0

  while array_of_strings[x].start_with?('#') do
    puts array_of_strings[x]
    x += 1
  end

  print "\n\n" if x>0 && verbose?
end


# Returns an Array of keywords or phrases that look like:
#   [KEYWORD]
#   [KEYWORD|KEYWORD]
#   [KEY PHRASE]
#   [KEY PHRASE | KEY PHRASE | KEY_WORD]
#
def extract_keywords_from(prompt_raw)
  prompt_raw.scan(KEYWORD_REGEX).flatten.uniq
end

# get the replacements for the keywords
def replacements_for(keywords)
  replacements = load_default_replacements

  keywords.each do |kw|
    default = replacements[kw]
    print "#{kw} (#{default}) ? "
    a_string          = Readline.readline("\n> ", false)
    replacements[kw]  = a_string unless a_string.empty?
  end

  save_default_replacements(replacements)

  replacements
end


def load_default_replacements
  if configatron.defaults_path.exist?
    JSON.parse(configatron.defaults_path.read)
  else
    {}
  end
end


def save_default_replacements(a_hash)
  return if a_hash.empty?
  defaults = a_hash.to_json
  configatron.defaults_path.write defaults
end

# substitute the replacements for the keywords
def replace_keywords_with replacements, prompt_raw
  prompt = prompt_raw.dup

  replacements.each_pair do |keyword, replacement|
    prompt.gsub!(keyword, replacement)
  end

  prompt
end


def log(prompt_path, prompt_raw, answer)
  f = File.open(PROMPT_LOG, "ab")

  f.write <<~EOS
    =======================================
    == #{Time.now}
    == #{prompt_path}

    PROMPT: #{prompt_raw}

    RESULT:
    #{answer}

  EOS
end


######################################################
# Main

at_exit do
  puts
  puts "Done."
  puts
end

ap configatron.to_h  if debug?

configatron.prompt_raw  = extract_raw_prompt

puts
puts "PROMPT:"
puts configatron.prompt_raw.wrap
puts


keywords      = extract_keywords_from configatron.prompt_raw
replacements  = replacements_for keywords

prompt = replace_keywords_with replacements, configatron.prompt_raw
ptompt = %Q{prompt}

command = AI_COMMAND + '"' + prompt + '"'

configatron.input_files.each do |input_file|
  command += " < #{input_file}"
end


print "\n\n" if verbose? && !keywords.empty?

if verbose?
  puts "="*42
  puts command
  puts "="*42
  print "\n\n"
end

result = `#{command}`

configatron.output.write result

log configatron.prompt_path, prompt, result


__END__

To specify a history and autocomplete options with the readline method in Ruby using the readline gem, you can follow these steps:

1. **History** - To enable history functionality, create a Readline::HISTORY object:
```ruby
history = Readline::HISTORY
```
You can then use the `history` object to add and manipulate history entries.

2. **Autocomplete** - To enable autocomplete functionality, you need to provide a completion proc to `Readline.completion_proc`:
```ruby
Readline.completion_proc = proc { |input|  ... }
```
You should replace `...` with the logic for determining the autocomplete options based on the input.

For example, you can define a method that provides autocomplete options based on a predefined array:
```ruby
def autocomplete_options(input)
  available_options = ['apple', 'banana', 'cherry']
  available_options.grep(/^#{Regexp.escape(input)}/)
end

Readline.completion_proc = proc { |input| autocomplete_options(input) }
```

In this example, the `autocomplete_options` method takes the user's input and uses the `grep` method to filter the available options based on the input prefix.

Remember to require the readline gem before using these features:
```ruby
require 'readline'
```

With the above steps in place, you can use the readline method in your code, and the specified history and autocomplete options will be available.

Note: Keep in mind that autocomplete options will only appear when tab is pressed while entering input.




