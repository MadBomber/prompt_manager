# Shell Integration

PromptManager can automatically substitute environment variables and integrate with shell commands.

## Environment Variables

Enable environment variable substitution:

```ruby
prompt = PromptManager::Prompt.new(
  id: 'system_prompt',
  envar_flag: true
)
```

Environment variables in your prompt text will be automatically replaced.

## Example

```text title="system_prompt.txt"
System: $USER
Home: $HOME
Path: $PATH

Working directory: <%= Dir.pwd %>
```

## Shell Command Execution

PromptManager also supports shell command substitution using `$(command)` syntax:

```text title="system_info.txt"
Current system load: $(uptime)
Disk usage: $(df -h / | tail -1)
Memory info: $(vm_stat | head -5)
```

Commands are executed when the prompt is processed, with output substituted in place.

## Advanced Example

The [advanced_integrations.rb](../../examples/advanced_integrations.rb) example demonstrates comprehensive shell integration:

```text
### Hardware Platform Details
**Architecture**: $HOSTTYPE$MACHTYPE
**Hostname**: $HOSTNAME  
**Operating System**: $OSTYPE
**Shell**: $SHELL (version: $BASH_VERSION)
**User**: $USER
**Home Directory**: $HOME
**Current Path**: $PWD
**Terminal**: $TERM

### Environment Configuration
**PATH**: $PATH
**Language**: $LANG
**Editor**: $EDITOR
**Pager**: $PAGER

### Performance Context
**Load Average**: <%= `uptime`.strip rescue 'Unable to determine' %>
**Memory Info**: <%= `vm_stat | head -5`.strip rescue 'Unable to determine' if RUBY_PLATFORM.include?('darwin') %>
**Disk Usage**: <%= `df -h / | tail -1`.strip rescue 'Unable to determine' %>
```

This creates dynamic prompts that capture real-time system information for analysis.

## Configuration

Set environment variables that your prompts will use:

```bash
export API_KEY="your-api-key"
export ENVIRONMENT="production"
export OPENAI_API_KEY="your-openai-key"
```

For more shell integration examples, see the [Examples documentation](../examples.md).