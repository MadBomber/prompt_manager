# PromptManager

Manage the parameterized prompts (text) used in generative AI (aka chatGPT, OpenAI, _et.al._) using storage adapters such as FileSystemAdapter, SqliteAdapter and ActiveRecordAdapter.

## Installation

Install the gem and add to the application's Gemfile by executing:

    bundle add prompt_manager

If bundler is not being used to manage dependencies, install the gem by executing:

    gem install prompt_manager

## Usage

See [examples/simple.rb](examples.simple.rb)

## Overview

### Generative AI (gen-AI)

Gen-AI deals with the conversion (some would say execution) of a human natural language text (the "prompt") into somthing else using what are known as large language models (LLM) such as those available from OpenAI.  A parameterized prompt is one in whcih there are embedded keywords (parameters) which are place holders for other text to be inserted into the prompt.

The prompt_manager uses a regurlar expression to identify these keywords within the prompt.  It uses the keywords as keys in a `parameters` Hash which is stored with the prompt text in a serialized form - for example as JSON.

#### What does a keyword look like?

The current hard-coded REGEX for a [KEYWORD] identifies any all [UPPERCASE_TEXT] enclosed in squal brackes as a keyword.  [KEY WORDS CAN ALSO HAVE SPACES] as well as the underscore character.

This is just the initial convention adopted by prompt_manager.  It is intended that this REGEX be configurable so that the promp_manager can be used with other conventions.

### Storage Adapters

A storage adapter is a class instance that ties the `PromptManager::Prompt` class to a storage facility that holds the actual prompts.  Currentlyt there are 3 storage adapters planned for implementation.

#### FileSystemAdapter

This is the first storage adapter developed.  It saves prompts as text files within the file system inside a designated `prompts_dir` (directory) such as `~/,prompts` or where it makes the most sense to you.  Another example would be to have your directory on a shared file system so that others can use the same prompts.

The `promp ID` is the basename of the text file.  For example `todo.txt` is the file for the prompt ID `todo` (see the examples directory.)

The parameters for the `todo` prompt ID are saved in the same directory as `todo.txt` in a JSON file named `todo.json` (also in the examples directory.)

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
