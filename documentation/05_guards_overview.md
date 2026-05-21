# Guards Overview

Guards are Agents running in validation mode. They receive user input, call a model, and return
an `InputResult` describing whether the input is safe and valid.

## How Guards Work

1. Each guard is called in registration order.
2. The previous guard's `processed` output becomes the next guard's `input`.
3. If any guard returns `safe: false` or `valid: false`, the pipeline is blocked immediately.
4. The final guard's `InputResult` is passed to the main agent's callbacks and prompt builder.

## Registering Guards

```ruby
class MyAgent < ActiveHarness::Agent
  guard InjectionGuard, name: :injection_guard
  guard ToxicityGuard,  name: :toxicity_guard
  guard TopicGuard,     name: :topic_guard, allowed_topics: ["Ruby", "programming"]
end
```

Options after `name:` are available inside the guard via `payload.options`.

## Creating a Guard

```ruby
class InjectionGuard < ActiveHarness::Agent
  model { use provider: :openrouter, model: "openai/gpt-4.1-mini" }
  prompt InjectionGuardPrompt
  system_language :en
  risk_tolerance  :low

  before { |payload, input| input.strip }
end
```

## InputResult Fields

| Field        | Type                         | Description                                 |
| ------------ | ---------------------------- | ------------------------------------------- |
| `safe?`      | Boolean                      | false → block if risk exceeds tolerance     |
| `valid?`     | Boolean                      | false → always block                        |
| `risk_level` | `:low` / `:medium` / `:high` | severity                                    |
| `processed`  | String                       | normalised/transformed input passed forward |
| `intent`     | String                       | model's description of user intent          |
| `reason`     | String                       | explanation of the decision                 |
| `errors`     | Array                        | validation error messages                   |

## Built-in Guards (Playground)

- **InjectionGuard** — detects prompt injection and instruction override attempts
- **ToxicityGuard** — detects profanity, hate speech, explicit threats
- **TopicGuard** — ensures question is on-topic (configurable `allowed_topics:`)
