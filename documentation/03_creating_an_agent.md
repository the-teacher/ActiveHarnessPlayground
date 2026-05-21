# Creating an Agent

Subclass `ActiveHarness::Agent` and use the DSL to configure it.

## Minimal Agent

```ruby
class MyAgent < ActiveHarness::Agent
  model { use provider: :openrouter, model: "openai/gpt-4.1-mini" }
  system_prompt "You are a helpful assistant."
  output :text
end

result = MyAgent.call(input: "What is Ruby?")
puts result.output
```

## Full DSL Reference

```ruby
class MyAgent < ActiveHarness::Agent
  # Language the agent operates in (affects guards)
  system_language :en

  # Guards run in order; first failure blocks the request
  guard InjectionGuard, name: :injection_guard
  guard ToxicityGuard,  name: :toxicity_guard

  # Model selection with fallback
  model do
    use      provider: :openrouter, model: "openai/gpt-4.1-mini"
    fallback provider: :openrouter, model: "google/gemma-3-4b-it:free"
  end

  # System prompt (String, class with .prompt, or lambda)
  system_prompt MySystemPrompt

  # Risk tolerance: :low (block medium+high), :medium, :high
  risk_tolerance :low

  # Default message shown when a guard blocks
  default_error_answer "Sorry, I can't help with that."

  # Setup runs once before the pipeline; mutate and return payload
  setup do |payload|
    payload.input = payload.input.strip.downcase
    payload
  end

  output :text
end
```

## Calling an Agent

```ruby
result = MyAgent.call(
  input:    "User's question",
  language: :en,          # optional
  context:  { user_id: 42 }  # optional, available in callbacks
)

if result.success?
  puts result.output
elsif result.blocked?
  puts result.output   # default_error_answer
else
  puts result.error.message
end
```

## Config Isolation

Each Agent subclass has its own isolated `agent_config`. Subclassing does not inherit config
from the parent class.
