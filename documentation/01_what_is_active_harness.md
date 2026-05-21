# What is ActiveHarness?

ActiveHarness is a Ruby framework for building AI agent pipelines. It provides a clean DSL for
connecting language model calls, input validation (guards), prompt management, and output parsing.

## Core Problems It Solves

- **Prompt injection & safety**: Guards validate every user input before it reaches the model.
- **Provider abstraction**: Swap OpenAI, Anthropic, OpenRouter, etc. with one config line.
- **Pipeline composability**: `before`/`after` callbacks transform input and output at each stage.
- **Structured output**: Agents declare `:text` or `:json` output with optional schema validation.

## Key Concepts

- **Agent** — the main class. Subclass `ActiveHarness::Agent`, declare DSL, call `.call(input:)`.
- **Guard** — an Agent used in validation mode; returns an `InputResult` (safe/unsafe).
- **Engine** — orchestrates the full pipeline: guards → prompt → model → output.
- **Payload** — unified request context (input, language, context, options) passed through all hooks.
- **Result** — the return value of `.call`; has `.success?`, `.blocked?`, `.failed?`, `.output`.

## Minimal Example

```ruby
class MyAgent < ActiveHarness::Agent
  model { use provider: :openrouter, model: "openai/gpt-4.1-mini" }
  system_prompt "You are a helpful assistant."
  output :text
end

result = MyAgent.call(input: "Hello!")
puts result.output  # => "Hello! How can I help you?"
```
