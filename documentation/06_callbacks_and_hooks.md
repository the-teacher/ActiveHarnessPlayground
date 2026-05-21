# Callbacks and Hooks

Callbacks intercept values at key points in the pipeline. Every callback receives two arguments
`(payload, current_value)` and must return the (possibly modified) value.

## Available Hooks

| Hook               | Receives                   | Expected return                         |
| ------------------ | -------------------------- | --------------------------------------- |
| `before(:guards)`  | `(payload, String)`        | String — input sent to first guard      |
| `after(:guards)`   | `(payload, InputResult)`   | InputResult                             |
| `before(:request)` | `(payload, Hash)`          | Hash `{ system: String, user: String }` |
| `after(:request)`  | `(payload, ModelResponse)` | ModelResponse                           |

## Registering Callbacks

```ruby
class MyAgent < ActiveHarness::Agent
  before(:guards) { |payload, input| input.strip.downcase }

  after(:guards) do |payload, result|
    # Side-effect: store doc content from guard result
    payload.context[:doc_file] = result.processed
    result
  end

  before(:request) do |payload, prompt|
    prompt.merge(system: prompt[:system] + "\nBe concise.")
  end

  after(:request) do |payload, response|
    response  # return unchanged, or wrap/log
  end
end
```

## Per-Guard Callbacks

Wrap individual guard calls:

```ruby
before(:guard, :injection_guard) { |payload, input| input.gsub(/\s+/, " ") }
after(:guard,  :injection_guard) { |payload, result| result }
```

## Guard-Mode Callbacks (inside a Guard class)

A guard's own before callback runs on its input before sending to the model:

```ruby
class InjectionGuard < ActiveHarness::Agent
  before { |payload, input| input.strip }
end
```

## Multiple Callbacks

Multiple callbacks for the same hook chain in registration order:

```ruby
before(:guards) { |payload, input| input.strip }
before(:guards) { |payload, input| input.downcase }
# → input is stripped, then downcased
```

## `setup` Hook

Runs once before any callbacks. Receives the full `Payload` object:

```ruby
setup do |payload|
  payload.meta[:started_at] = Time.now
  payload.input = payload.input.strip
  payload  # must return the payload
end
```
