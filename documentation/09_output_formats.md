# Output Formats

Agents declare their expected output type with the `output` DSL.

## Text Output

```ruby
output :text
```

The model's raw response string is returned as-is in `result.output`.

## JSON Output

```ruby
output :json
```

The model's response is parsed with `JSON.parse`. `result.output` is a Ruby Hash.

## JSON with Schema Validation

```ruby
output :json, schema: {
  answer:    String,
  source:    String,
  confident: Object  # any truthy type check
}
```

`OutputParser` checks that every key in the schema exists in the parsed hash. Raises
`Errors::SchemaValidationError` if a key is missing. The values in the schema hash are
currently used as documentation; type checking is key-presence only.

## Example: JSON Agent

```ruby
class FactAgent < ActiveHarness::Agent
  model { use provider: :openrouter, model: "openai/gpt-4.1-mini" }
  system_prompt "Respond ONLY with JSON: { \"fact\": \"...\", \"source\": \"...\" }"
  output :json, schema: { fact: String, source: String }
end

result = FactAgent.call(input: "Tell me about Ruby")
puts result.output["fact"]
puts result.output["source"]
```

## Error Handling

| Error                           | Cause                                              |
| ------------------------------- | -------------------------------------------------- |
| `Errors::SchemaValidationError` | Model returned invalid JSON or missing schema keys |
| `Errors::ConfigurationError`    | Unknown output type declared                       |

Both are caught by `Engine` and returned as `Result.failed(error: ...)`.

## Accessing Output

```ruby
result = MyAgent.call(input: "...")

if result.success?
  puts result.output        # String or Hash depending on output type
  puts result.raw_response  # always the raw model string
end
```
