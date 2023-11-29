# PromptManager

Manage the parameterized prompts (text) used in generative AI (aka chatGPT, OpenAI, _et.al._) using storage adapters such as FileSystemAdapter, SqliteAdapter and ActiveRecordAdapter.

**Breaking Change** in version 0.3.0 - The value of the parameters Hash for a keyword is now an Array instead of a single value.  The last value in the Array is always the most recent value used for the given keyword.  This was done to support the use of a Readline::History object editing in the [aia](https://github.com/MadBomber/aia) CLI tool


<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

  - [Installation](#installation)
  - [Usage](#usage)
  - [Overview](#overview)
    - [Generative AI (gen-AI)](#generative-ai-gen-ai)
      - [What does a keyword look like?](#what-does-a-keyword-look-like)
    - [Storage Adapters](#storage-adapters)
      - [FileSystemAdapter](#filesystemadapter)
        - [Configuration](#configuration)
          - [prompts_dir](#prompts_dir)
          - [search_proc](#search_proc)
          - [File Extensions](#file-extensions)
        - [Example Prompt Text File](#example-prompt-text-file)
        - [Example Prompt Parameters JSON File](#example-prompt-parameters-json-file)
        - [Extra Functionality](#extra-functionality)
      - [SqliteAdapter](#sqliteadapter)
      - [ActiveRecordAdapter](#activerecordadapter)
      - [Other Potential Storage Adapters](#other-potential-storage-adapters)
  - [Development](#development)
  - [Contributing](#contributing)
  - [License](#license)

<!-- Tocer[finish]: Auto-generated, don't remove. -->

## Installation

Install the gem and add to the application's Gemfile by executing:

    bundle add prompt_manager

If bundler is not being used to manage dependencies, install the gem by executing:

    gem install prompt_manager

## Usage

See [examples/simple.rb](examples/simple.rb)

## Overview

### Generative AI (gen-AI)

Gen-AI deals with the conversion (some would say execution) of a human natural language text (the "prompt") into somthing else using what are known as large language models (LLM) such as those available from OpenAI.  A parameterized prompt is one in which there are embedded keywords (parameters) which are place holders for other text to be inserted into the prompt.

The prompt_manager uses a regular expression to identify these keywords within the prompt. It uses the keywords as keys in a `parameters` Hash which is stored with the prompt text in a serialized form - for example as JSON.

#### What does a keyword look like?

The current hard-coded REGEX for a [KEYWORD] identifies any all [UPPERCASE_TEXT] enclosed in square brackets as a keyword. [KEYWORDS CAN ALSO HAVE SPACES] as well as the underscore character.

This is just the initial convention adopted by prompt_manager. It is intended that this REGEX be configurable so that the prompt_manager can be used with other conventions.

### Storage Adapters

A storage adapter is a class instance that ties the `PromptManager::Prompt` class to a storage facility that holds the actual prompts. Currently there are 3 storage adapters planned for implementation.

The `PromptManager::Prompt` to support a small set of methods.  A storage adapter can provide "extra" class or instance methods that can be used through the Prompt class.  See the `test/prompt_manager/prompt_test.rb` for guidance on creating a new storage adapter.

#### FileSystemAdapter

This is the first storage adapter developed. It saves prompts as text files within the file system inside a designated `prompts_dir` (directory) such as `~/.prompts` or where it makes the most sense to you.  Another example would be to have your directory on a shared file system so that others can use the same prompts.

The `prompt ID` is the basename of the text file. For example `todo.txt` is the file for the prompt ID `todo` (see the examples directory.)

The parameters for the `todo` prompt ID are saved in the same directory as `todo.txt` in a JSON file named `todo.json` (also in the examples directory.)

##### Configuration

Use a `config` block to establish the configuration for the class.

```ruby
PromptManager::Storage::FileSystemAdapter.config do |o|
  o.prompts_dir = "path/to/prompts_directory" 
  o.search_proc = -> (q) { "ag -l #{q} #{prompts_dir} | reformat" } 
  o.prompt_extension = '.txt' # default
  o.params_extension = '.json' # the default
end
```

The `config` block returns `self` so that means you can do this to setup the storage adapter with the Prompt class:

```ruby
PromptManager::Prompt
  .storage_adapter = 
    PromptManager::Storage::FileSystemAdapter
      .config do |config|
        config.prompts_dir = 'path/to/prompts_dir'
      end.new
```

###### prompts_dir

This is either a `String` or a `Pathname` object.  All file paths are maintained in the class as `Pathname` objects.  If you provide a `String` it will be converted.  Relative paths will be converted to absolute paths.

An `ArgumentError` will be raised when `prompts_dir` does not exist or if it is not a directory.

###### search_proc

The default for `search_proc` is nil.  In this case the search will be preformed by a default `search` method which is basically reading all the prompt files to see which ones contain the search term.  There are faster ways to do this kind of thing using CLI=based utilities.

TODO: add a example to the examples directory on how to integrate with command line utilities.

###### File Extensions

These two configuration options are `String` objects that must start with a period "." utherwise an `ArgumentError` will be raised.

* prompt_extension - default: '.txt'
* params_extension - default: '.json'

Currently the `FileSystemAdapter` only supports a JSON serializer for its parameters Hash.  Using any other values for these extensions will cause problems.

They exist so that there is a platform on to which other storage adapters can be built or serializers added.  This is not currently on the roadmap.

##### Example Prompt Text File

```text
# ~/.prompts/joke.txt
# Desc: Tell some jokes

Tell me a few [KIND] jokes about [SUBJECT]
```

Note the command lines at the top.  This is a convention I use.  It is not part of the software.  I find it helpful in documenting the prompt.

##### Example Prompt Parameters JSON File

```json
{
  "[KIND]": [
    "pun",
    "family friendly"
  ],
  "[SUBJECT]": [
    "parrot",
    "garbage man",
    "snowman",
    "weather girl"
  ]
}
```

The last value in the keyword's Array is the most recent value used for that keyword.  This is a functionality established since v0.3.0.  Its purpose is to provide a history of values from which a user can select to repeat a previous value or to select ta previous value and edit it into something new.

##### Extra Functionality

The `FileSystemAdapter` adds two new methods for use by the `Prompt` class:
* list - returns an Array of prompt IDs
* path and path(prompt_id) - returns a `Pathname` object to the prompt file

Use the `path(prompt_id)` form against the `Prompt` class
Use `prompt.path` when you have an instance of a `Prompt`

#### SqliteAdapter

TODO: This may be the next adapter to be implemented.

#### ActiveRecordAdapter

TODO: Still looking for requirements on how to integrate with an existing `rails` app.  Looking for ideas.

#### Other Potential Storage Adapters

There are many possibilities to example this plugin concept of the storage adapter.  Here are some for consideration:

* RedisAdapter - Not sure; isn't redis more temporary oriented?
* ApiAdapter - use some end-point to CRUD a prompt

## Development

Looking for feedback and contributors to enhance the capability of prompt_manager.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/prompt_manager.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
