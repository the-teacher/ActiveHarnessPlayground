# Guard Retries and Error Handling

Guards require the model to respond with valid JSON matching a specific schema. If the response
is invalid, ActiveHarness retries automatically.

## How Retries Work

1. `GuardRunner` calls the model.
2. `parse_guard_response` validates the JSON and required fields (`safe`, `valid`, `risk_level`, `processed`).
3. If validation fails, a corrective user message is appended to the conversation and the model is called again.
4. After all retries are exhausted, the guard returns `safe: false`, `valid: false`, `risk_level: :high`.

## Configuring Retries

**Global default** (applies to all guards):

```ruby
ActiveHarness.configure do |config|
  config.guard_retries = 2  # 1 initial attempt + 2 retries = 3 total
end
```

**Per guard class** (overrides global):

```ruby
class InjectionGuard < ActiveHarness::Agent
  guard_retries 3  # up to 4 total attempts
  # ...
end
```

## Errors

| Error class                      | When raised                                              |
| -------------------------------- | -------------------------------------------------------- |
| `Errors::GuardResponseError`     | JSON invalid or required fields missing (triggers retry) |
| `Errors::ProviderError`          | All model providers failed                               |
| `Errors::ThrottleError`          | Rate limit exceeded for the user                         |
| `Errors::ContextValidationError` | Required context param missing                           |
| `Errors::SchemaValidationError`  | Agent output JSON invalid or schema mismatch             |
| `Errors::ConfigurationError`     | Unknown output type, missing model config                |

## Exhaustion Fallback

When all retry attempts fail, `GuardRunner` returns a synthetic blocked `InputResult`:

```ruby
InputResult.new(
  safe:       false,
  valid:      false,
  risk_level: :high,
  errors:     ["Guard validation failed after N attempt(s): <last error>"]
)
```

This causes `Engine` to return `Result.blocked(...)`.

## Accessing Error Info

```ruby
result = MyAgent.call(input: "...")

if result.failed?
  puts result.error.class    # e.g. Errors::ProviderError
  puts result.error.message
end

if result.blocked?
  puts result.input.errors   # Array of guard error messages
  puts result.input.reason
end
```
