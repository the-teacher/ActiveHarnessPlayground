# Payload and Context

`Payload` is the unified request context that flows through the entire pipeline — setup, callbacks,
guards, and the main request.

## Payload Fields

| Field       | Type          | Description                                                                                          |
| ----------- | ------------- | ---------------------------------------------------------------------------------------------------- |
| `input`     | String        | current working input (may be mutated by setup/callbacks)                                            |
| `context`   | Hash          | arbitrary data passed via `.call(context: {...})`                                                    |
| `language`  | Symbol/String | target language hint (e.g. `:ru`, `:en`); drives "Respond in X" instruction                          |
| `translate` | Callable/nil  | I18n callable — `.(key)` returns a localized string; e.g. `Playground::I18n.translator(locale: :ru)` |
| `options`   | Hash          | per-guard options from registry                                                                      |
| `meta`      | Hash          | agent-internal metadata (timings, flags, etc.)                                                       |

## Passing Context from the Caller

```ruby
result = MyAgent.call(
  input:    "What is Ruby?",
  language: :ru,
  context:  { user_id: 42, plan: :pro },
  translate: ->(text, from:, to:) { MyTranslator.translate(text, from: from, to: to) }
)
```

## Reading Context in Callbacks

```ruby
before(:request) do |payload, prompt|
  user_plan = payload.context[:plan]
  extra = user_plan == :pro ? "\nProvide detailed examples." : ""
  prompt.merge(system: prompt[:system] + extra)
end
```

## Mutating Context as a Side-Channel

Since `payload` is an object (not frozen), callbacks can write to `payload.context` and later
callbacks will see those changes:

```ruby
after(:guards) do |payload, result|
  payload.context[:doc_content] = File.read("docs/#{result.processed}")
  result
end

before(:request) do |payload, prompt|
  doc = payload.context[:doc_content]
  prompt.merge(system: "#{prompt[:system]}\n\n#{doc}")
end
```

## Guard-Specific Options via `payload.options`

Options registered with a guard are available inside that guard's callbacks and prompt lambda:

```ruby
# Registration:
guard TopicGuard, name: :topic_guard, allowed_topics: ["Ruby"]

# Inside TopicGuard's system_prompt lambda:
system_prompt ->(context, options) {
  "Only allow: #{options[:allowed_topics].join(', ')}"
}
```
