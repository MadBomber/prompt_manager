# PromptManager

<div align="left">
  <img src="prompt_manager_logo.png" alt="PromptManager - The Enchanted Librarian of AI Prompts" width="1200"
      align="left" style="margin-right: 20px; margin-bottom: 20px;">

  **Manage the parameterized prompts (text) used in generative AI (aka chatGPT, OpenAI, _et.al._) using storage adapters such as FileSystemAdapter and ActiveRecordAdapter.**

  Like an enchanted librarian organizing floating books of knowledge, PromptManager helps you masterfully orchestrate and organize your AI prompts through wisdom and experience. Each prompt becomes a living entity that can be categorized, parameterized, and interconnected with golden threads of relationships.

  ## Key Features

  - **📚 Multiple Storage Adapters** - FileSystem and ActiveRecord storage with extensible adapter architecture
  - **🔧 Parameterized Prompts** - Use `[KEYWORDS]` or `{{params}}` for dynamic content substitution
  - **📋 Directive Processing** - Support for `//include` and `//import` directives with loop protection
  - **🎨 ERB Integration** - Full ERB support for complex prompt generation
  - **🌍 Shell Integration** - Full integration supporting scripts and envars
  - **📖 Inline Documentation** - Support for line and block comments__`
  - **📊 Parameter History** - Maintains history of parameter values for easy reuse
  - **⚡ Error Handling** - Comprehensive error classes for better debugging
  - **🔌 Extensible Architecture** - Easy to extend with custom adapters and processors
</div>

<div style="clear: both;"></div>

<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

  * [Installation](#installation)
  * [Usage](#usage)
  * [Overview](#overview)
    * [Prompt Initialization Options](#prompt-initialization-options)
    * [Generative AI (gen\-AI)](#generative-ai-gen-ai)
      * [What does a keyword look like?](#what-does-a-keyword-look-like)
      * [All about directives](#all-about-directives)
        * [Example Prompt with Directives](#example-prompt-with-directives)
        * [Accessing and Setting Parameter Values](#accessing-and-setting-parameter-values)
        * [Dynamic Directives](#dynamic-directives)
        * [Executing Directives](#executing-directives)
      * [Comments Are Ignored](#comments-are-ignored)
  * [Storage Adapters](#storage-adapters)
    * [FileSystemAdapter](#filesystemadapter)
      * [Configuration](#configuration)
        * [prompts\_dir](#prompts_dir)
        * [search\_proc](#search_proc)
        * [File Extensions](#file-extensions)
      * [Example Prompt Text File](#example-prompt-text-file)
      * [Example Prompt Parameters JSON File](#example-prompt-parameters-json-file)
      * [Extra Functionality](#extra-functionality)
    * [ActiveRecordAdapter](#activerecordadapter)
      * [Configuration](#configuration-1)
        * [model](#model)
        * [id\_column](#id_column)
        * [text\_column](#text_column)
        * [parameters\_column](#parameters_column)
    * [Other Potential Storage Adapters](#other-potential-storage-adapters)
  * [Roadmap](#roadmap)
    * [v0\.9\.0 \- Modern Prompt Format (Breaking Changes)](#v090---modern-prompt-format-breaking-changes)
    * [v1\.0\.0 \- Stability Release](#v100---stability-release)
    * [Future Enhancements](#future-enhancements)
    * [What's Staying the Same](#whats-staying-the-same)
  * [Development](#development)
  * [Contributing](#contributing)
  * [License](#license)


## Installation

Install the gem and add to the application's Gemfile by executing:

    bundle add prompt_manager

If bundler is not being used to manage dependencies, install the gem by executing:

    gem install prompt_manager

## Usage

See [examples/simple.rb](examples/simple.rb)

See also [examples/using_search_proc.rb](examples/using_search_proc.rb)

## Overview

### Prompt Initialization Options
- `id`: A String name for the prompt.
- `context`: An Array for additional context.
- `directives_processor`: An instance of PromptManager::DirectiveProcessor (default), can be customized.
- `external_binding`: A Ruby binding to be used for ERB processing.
- `erb_flag`: Boolean flag to enable ERB processing in the prompt text.
- `envar_flag`: Boolean flag to enable environment variable substitution in the prompt text.

The `prompt_manager` gem provides functionality to manage prompts that have keywords and directives for use with generative AI processes.

### Generative AI (gen-AI)

Gen-AI deals with the conversion (some would say execution) of a human natural language text (the "prompt") into something else using what are known as large language models (LLM) such as those available from OpenAI.  A parameterized prompt is one in which there are embedded keywords (parameters) which are place holders for other text to be inserted into the prompt.

The prompt_manager uses a regular expression to identify these keywords within the prompt. It uses the keywords as keys in a `parameters` Hash which is stored with the prompt text in a serialized form - for example as JSON.

#### What does a keyword look like?

By default, any text matching `[UPPERCASE_TEXT]` enclosed in square brackets is treated as a keyword. [KEYWORDS CAN ALSO HAVE SPACES] as well as the underscore character.

You can customize the keyword pattern by setting a different regular expression:

```ruby
# Use {{param}} style instead of [PARAM]
PromptManager::Prompt.parameter_regex = /(\{\{[A-Za-z_]+\}\})/
```

The regex must include capturing parentheses () to extract the keyword. The default regex is `/(\[[A-Z _|]+\])/`.
#### All about directives

A directive is a line in the prompt text that starts with the two characters '//' - slash slash - just like in the old days of IBM JCL - Job Control Language.  A prompt can have zero or more directives.  Directives can have parameters and can make use of keywords.

The `prompt_manager` collects directives and provides a DirectiveProcessor class that currently implements the `//include` directive (also aliased as `//import`), which allows including content from other files with loop protection. It extracts keywords from directive lines and provides the substitution of those keywords with other text just like it does for the prompt.

##### Example Prompt with Directives

Here is an example prompt text file with comments, directives and keywords:

```text
# prompts/sing_a_song.txt
# Desc: Has the computer sing a song

//TextToSpeech [LANGUAGE] [VOICE NAME]

Say the lyrics to the song [SONG NAME].  Please provide only the lyrics without commentary.

__END__
Computers will never replace Frank Sinatra
```

##### Accessing and Setting Parameter Values

Getting and setting keywords from a prompt is straightforward:

```ruby
prompt = PromptManager::Prompt.new(id: 'some_id')
prompt.keywords   #=> an Array of keywords found in the prompt text

# Update the parameters hash with keyword values
prompt.parameters = {
  "[KEYWORD1]" => "value1",
  "[KEYWORD2]" => "value2"
}

# Build the final prompt text
# This substitutes values for keywords and processes directives
# Comments are removed and the result is ready for the LLM
final_text = prompt.to_s

# Save any parameter changes back to storage
prompt.save
```

Internally, directives are stored in a Hash where each key is the full directive line (including the // characters) and the value is the result string from executing that directive. The directives are processed in the order they appear in the prompt text.

##### Dynamic Directives

Since directies are collected after the keywords in the prompt have been substituted for their values, it is possible to have dynamically generated directives as part of a prompt.  For example:

```text
//[COMMAND] [OPTIONS]
# or
[SOMETHING]
```
... where [COMMAND] gets replaced by some directive name.  [SOMETHING] could be replaced by "//directive options"

##### Executing Directives

The `prompt_manager` gem provides a basic DirectiveProcessor class that handles the `//include` directive (aliased as `//import`), which adds the contents of a file to the prompt with loop protection to prevent circular includes.

Additionally, you can extend with your own directives or downstream processes. Here are some ideas on how directives could be used in prompt downstream process:

- "//model gpt-5" could be used to set the LLM model to be used for a specific prompt.
- "//backend mods" could be used to set the backend prompt processor on the command line to be the `mods` utility.
- "//chat" could be used to send the prompts and then start up a chat session about the prompt and its response.

Its all up to how your application wants to support directives or not.


#### Comments Are Ignored

The `prompt_manager` gem ignores comments.  A line that begins with the '#' - pound (aka hash) character - is a line comment.  Any lines that follow a line that is '__END__ at the end of a file are considered comments.  Basically the '__END__' the end of the file.  Nothing is process following that line.

The gem also ignores blank lines.

## Storage Adapters

A storage adapter is a class instance that ties the `PromptManager::Prompt` class to a storage facility that holds the actual prompts. Currently there are 2 storage adapters implemented: FileSystemAdapter and ActiveRecordAdapter.

The `PromptManager::Prompt` to support a small set of methods.  A storage adapter can provide "extra" class or instance methods that can be used through the Prompt class.  See the `test/prompt_manager/prompt_test.rb` for guidance on creating a new storage adapter.

### FileSystemAdapter

This is the first storage adapter developed. It saves prompts as text files within the file system inside a designated `prompts_dir` (directory) such as `~/.prompts` or where it makes the most sense to you.  Another example would be to have your directory on a shared file system so that others can use the same prompts.

The `prompt ID` is the basename of the text file. For example `todo.txt` is the file for the prompt ID `todo` (see the examples directory.)

The parameters for the `todo` prompt ID are saved in the same directory as `todo.txt` in a JSON file named `todo.json` (also in the examples directory.)

#### Configuration

Use a `config` block to establish the configuration for the class.

```ruby
PromptManager::Storage::FileSystemAdapter.config do |o|
  o.prompts_dir       = "path/to/prompts_directory"
  o.search_proc       = nil     # default
  o.prompt_extension  = '.txt'  # default
  o.params_extension  = '.json' # default
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

##### prompts_dir

This is either a `String` or a `Pathname` object.  All file paths are maintained in the class as `Pathname` objects.  If you provide a `String` it will be converted.  Relative paths will be converted to absolute paths.

An `ArgumentError` will be raised when `prompts_dir` does not exist or if it is not a directory.

##### search_proc

The default for `search_proc` is nil which means that the search will be preformed by a default `search` method which is basically reading all the prompt files to see which ones contain the search term. It will return an Array of prompt IDs for each prompt file found that contains the search term.  Its up to the application to select which returned prompt ID to use.

There are faster ways to search and select files.  For example there are specialized search and selection utilities that are available for the command line. The `examples` directory contains a `bash` script named `rgfzf` that uses `rg` (aka `ripgrep`) to do the searching and `fzf` to do the selecting.

See [examples/using_search_proc.rb](examples/using_search_proc.rb)

##### File Extensions

These two configuration options are `String` objects that must start with a period "." utherwise an `ArgumentError` will be raised.

* prompt_extension - default: '.txt'
* params_extension - default: '.json'

Currently the `FileSystemAdapter` only supports a JSON serializer for its parameters Hash.  Using any other values for these extensions will cause problems.

They exist so that there is a platform on to which other storage adapters can be built or serializers added.  This is not currently on the roadmap.

#### Example Prompt Text File

```text
# ~/.prompts/joke.txt
# Desc: Tell some jokes

Tell me a few [KIND] jokes about [SUBJECT]
```

Note the command lines at the top.  This is a convention I use.  It is not part of the software.  I find it helpful in documenting the prompt.

#### Example Prompt Parameters JSON File

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

#### Extra Functionality

The `FileSystemAdapter` adds two new methods for use by the `Prompt` class:

- list - returns an Array of prompt IDs
- path and path(prompt_id) - returns a `Pathname` object to the prompt file

Use the `path(prompt_id)` form against the `Prompt` class
Use `prompt.path` when you have an instance of a `Prompt`

### ActiveRecordAdapter

The `ActiveRecordAdapter` assumes that there is a database already configured by the application program that is requiring `prompt_manager` which has a model that contains prompt content.  This model must have at least three columns which contain content for:

- a prompt ID
- prompt text
- prompt parameters

The model and the columns for these three elements can have any name.  Those names are provided to the `ActiveRecordAdapter` in its config block.


#### Configuration

Use a `config` block to establish the configuration for the class.

The `PromptManager::Prompt` class expects an instance of a storage adapter class.  By convention storage adapter class config methods will return `self` so that a simple `new` after the config will establish the instance.

```ruby
PromptManager::Prompt
  .storage_adapter =
    PromptManager::Storage::ActiveRecordAdapter.config do |config|
      config.model              = DbPromptModel # any ActiveRecord::Base model
      config.id_column          = :prompt_name
      config.text_column        = :prompt_text
      config.parameters_column  = :prompt_params
    end.new # adapters an instances of the adapter class
```

##### model
The `model` configuration parameter is the actual class name of the `ActiveRecord::Base` or `ApplicationRecord` (if you are using a rails application) that contains the content used for prompts.

##### id_column
The `id_column` contains the name of the column that contains the "prompt ID" content.  It can be either a `String` or `Symbol` value.

##### text_column
The `text_column` contains name of the column that contains the actual raw text of the prompt.  This raw text can include the keywords which will be replaced by values from the parameters Hash.  The column name value can be either a `String` or a `Symbol`.

##### parameters_column
The `parameters_column` contains the name of the column that contains the parameters used to replace keywords in the prompt text.  This column in the database model is expected to be serialized.  The `ActiveRecordAdapter` currently has a kludge bit of code that assumes that the serialization is done with JSON.  The value of the parameters_column can be either a `String` or a `Symbol`.

TODO: fix the kludge so that any serialization can be used.

### Other Potential Storage Adapters

There are many possibilities to expand this plugin concept of the storage adapter.  Here are some for consideration:

- RedisAdapter - For caching prompts or temporary storage
- ApiAdapter - Use some end-point to CRUD a prompt
- CloudStorageAdapter - Store prompts in cloud storage services

## Roadmap

The PromptManager gem is actively evolving to meet the changing needs of the AI development community. Here's what's coming:

### v0.9.0 - Modern Prompt Format (Breaking Changes)
- **Markdown Support**: Full `.md` file support with YAML front matter for metadata and LLM configuration
- **Modern Parameter Syntax**: Support for `{{keyword}}` format alongside existing `[KEYWORD]` format
- **Enhanced API**: New `set_parameter()` and `get_parameter()` methods for cleaner parameter management
- **Parameter Validation**: Built-in validation based on parameter specifications in front matter
- **HTML Comments**: Support for `<!-- comments -->` that are stripped before sending to LLMs
- **Migration Tools**: Automated conversion from current format to new Markdown-based format
- **Preserving `__END__`**: Continued support for the `__END__` marker for developer notes

### v1.0.0 - Stability Release
- Performance optimizations and bug fixes
- Complete documentation with migration guides
- Production hardening based on v0.9.0 feedback

### Future Enhancements
- Additional storage adapters (Redis, S3, PostgreSQL)
- Enhanced directive system with plugin architecture
- Prompt versioning and template inheritance
- Performance optimizations for large prompt collections

### What's Staying the Same
- JCL-style directives (`//include`, `//import`)
- JSON serialization as the default
- Internal parameter storage format for backward compatibility
- All existing functionality continues to work

For detailed information about planned improvements, implementation strategies, and technical specifications, see our comprehensive [Improvement Plan](improvement_plan.md).

## Development

Looking for feedback and contributors to enhance the capability of prompt_manager.

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/MadBomber/prompt_manager](https://github.com/MadBomber/prompt_manager).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
