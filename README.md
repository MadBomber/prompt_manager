# PromptManager

**Under Development**  Not ready for use.

I'm looking for some contributors to help define the API between the Prompt class and the Storage adapters.  I'm focusing on the FileSystemAdapter since the majority of my work is on the command line. 

Extracting the prompt management functionality fro the aip.rb file into a new gem that will provide a generic management service for other programs.

## AIP.RB Legacy Summary of Capability

This is just some source material for later documentation.

### README for aip.rb

#### Overview

The `aip.rb` Ruby script is a command-line interface (CLI) tool designed to leverage generative AI with saved parameterized prompts. It integrates with the `mods` command-line tool that uses a GPT-based model to generate responses based on user-provided prompts. The script offers an array of features that make interacting with AI models more convenient and streamlined. 

#### Features

- **Prompt Management**
  - Users can select prompts from a saved collection with the help of command-line searching and filtering.
  - Prompts can be edited by the user to better fit their specific context or requirement.
  - Support for reading input from files to provide context for AI generation is included.
  
- **AI Integration**
  - The script interacts with `mods`, a generative AI utilizing GPT-based models, to produce outputs from the prompts.
  
- **Output Handling**
  - Generated content is saved to a specified file for record-keeping and further use.
  
- **Activity Logging**
  - All actions, including prompt usage and AI output, are logged with timestamps for review and auditing purposes.

#### Dependencies

The script requires the installation of the following command-line tools:

- `fzf`: a powerful command-line fuzzy finder.
- `mods`: an AI-powered CLI tool for generative AI interactions.
- `the_silver_searcher (ag)`: a code-searching tool similar to ack and used for searching prompts.

#### Usage

The `aip.rb` script offers a set of command-line options to guide the interaction with AI:

- `-p, --prompt`: Specify the prompt name to be used.
- `-e, --edit`: Open the prompt text for editing before generation.
- `-f, --fuzzy`: Allows fuzzy matching for prompt selection.
- `-o, --output`: Sets the output file for the generated content.

Additional flags and options can be passed to the `mods` tool by appending them after a `--` separator.

#### Installation

Before using the script, one must ensure the required command-line tools (`fzf`, `mods`, and `the_silver_searcher`) are installed, and the Ruby environment is correctly set up with the necessary gems.

#### Development Notes

The author suggests that the script has matured enough to be converted into a Ruby gem for easier distribution and installation.

#### Getting Help

For help with using the CLI tool or further understanding the `mods` command, users can refer to the AI CLI Program help section included in the script or by invoking the `--help` flag.

#### Conclusion

The `aip.rb` script is designed to offer a user-friendly and flexible approach to integrating generative AI into content creation processes. It streamlines the interactions and management of AI-generated content by providing prompt management, AI integration, and logging capabilities, packaged inside a simple command-line utility.





## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

    $ bundle add UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/prompt_manager.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
