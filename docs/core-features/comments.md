# Comments and Documentation

PromptManager supports comprehensive inline documentation through comments and special sections.

## Line Comments

Lines beginning with `#` are treated as comments and ignored during processing:

```text
# This is a comment describing the prompt
# Author: Your Name
# Version: 1.0

Hello [NAME]! This text will be processed.
```

## Block Comments

Everything after `__END__` is ignored, creating a documentation section:

```text
Your prompt content here...

__END__
This section is completely ignored by PromptManager.

Development notes:
- TODO: Add more parameters
- Version history
- Usage examples
```

## Documentation Best Practices

```text
# Description: Customer service greeting template
# Tags: customer-service, greeting
# Version: 1.2
# Author: Support Team
# Last Updated: 2024-01-15

//include common/header.txt

Your prompt content...

__END__
Internal notes and documentation go here.
```