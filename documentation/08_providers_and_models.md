# Providers and Models

ActiveHarness supports multiple LLM providers. Use the `model` block to configure primary and
fallback providers.

## Supported Providers

| Key           | Provider   | Notes                              |
| ------------- | ---------- | ---------------------------------- |
| `:openrouter` | OpenRouter | Access 100+ models via one API key |
| `:openai`     | OpenAI     | Direct API                         |
| `:anthropic`  | Anthropic  | Stub — not yet implemented         |
| `:google`     | Google     | Stub — not yet implemented         |

## Model Block DSL

```ruby
model do
  use      provider: :openrouter, model: "openai/gpt-4.1-mini"
  fallback provider: :openrouter, model: "google/gemma-3-4b-it:free"
  fallback provider: :openai,     model: "gpt-4o-mini"
end
```

`FallbackRunner` tries each entry in order, stopping at the first success.

## API Key Configuration

```ruby
ActiveHarness.configure do |config|
  config.openrouter_api_key = ENV["OPENROUTER_API_KEY"]
  config.openai_api_key     = ENV["OPENAI_API_KEY"]
end
```

## Global Defaults

```ruby
ActiveHarness.configure do |config|
  config.default_temperature = 0.2   # 0.0–1.0
  config.default_timeout     = 30    # seconds
end
```

## FallbackRunner Behaviour

- Tries providers in order.
- Skips on timeout, network error, or `InvalidAPIKey`.
- Raises `Errors::ProviderError` if all entries fail.
- Records each attempt in `Result#attempts`:
  ```ruby
  result.attempts.each { |a| puts "#{a[:model]} → #{a[:status]}" }
  ```

## Rate Limiting

Register limits per user:

```ruby
ActiveHarness.configure do |config|
  config.rate_limit_per_minute = 10
end
```

Pass `context: { user_id: 42 }` to `.call` to track per-user rates.
