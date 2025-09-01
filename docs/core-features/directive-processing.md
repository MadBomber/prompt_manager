# Directive Processing

Directives are special instructions in your prompts that begin with `//` and provide powerful prompt composition capabilities.

## Overview

Directives allow you to:
- Include content from other files
- Create modular, reusable prompt components
- Build dynamic prompt structures
- Process commands during prompt generation

## Built-in Directives

### `//include` (alias: `//import`)

Include content from other files:

```text
//include common/header.txt
//import templates/[TEMPLATE_TYPE].txt

Your main prompt content here...
```

## Example

```text title="customer_response.txt"
//include common/header.txt

Dear [CUSTOMER_NAME],

Thank you for your inquiry about [TOPIC].

//include common/footer.txt
```

For detailed examples and advanced usage, see the [Basic Examples](../examples/basic.md).