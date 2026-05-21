# Language and Localization

ActiveHarness separates two distinct language concerns: the **system language** for internal
pipeline processing, and the **user language** for responses and UI text.

## Two Language Concepts

| Concept           | DSL / Parameter        | Purpose                                                  |
| ----------------- | ---------------------- | -------------------------------------------------------- |
| `system_language` | `system_language :en`  | Language guards use for their `processed` output field   |
| `language`        | `.call(language: :ru)` | Language the agent responds in; also drives localization |

### System Language (`system_language`)

Set on a guard class. Guards always produce their `processed` field in this language regardless
of what language the user sent the input in.

```ruby
class InjectionGuard < ActiveHarness::Agent
  system_language :en
  # ...
end
```

This means a Korean user input `"루비에서 에이전트를 만드는 방법은?"` comes out of the guard
chain as `"How do I create an agent in Ruby?"` — a normalized English string that every
downstream component understands.

A global default can be set in the configure block so individual guards don't need to repeat it:

```ruby
ActiveHarness.configure do |config|
  config.default_language = :en
end
```

Priority: `payload.language` > `system_language :xx` on the guard class > `config.default_language` > `:en`.

### User Language (`language`)

Passed at call time. Tells the main agent what language to reply in.

```ruby
result = MyAgent.call(
  input:    "Как создать агента?",
  language: :ru,
  context:  {}
)
```

`PromptBuilder` automatically appends `"Respond in the following language: ru."` to the system
prompt so the LLM always replies in the requested language, regardless of what language the
system prompt itself is written in.

## Do You Need a Translator Agent?

**No.** Guards already normalize user input into the system language via their `processed` field.
Modern LLMs handle multilingual input well and a separate translation round-trip would just
add latency and cost.

The flow looks like this:

```
User input: "Покажи пример before/after callback"  (Russian)
     │
     ▼ InjectionGuard (system_language :en)
     │   processed = "Show me example of before/after callback"
     │
     ▼ RelevanceGuard
     │   processed = "06_callbacks_and_hooks.md"
     │
     ▼ SupportAgent ← PromptBuilder
         system: "...Respond in the following language: ru."
         user:   "Покажи пример before/after callback"  (original restored)
     │
     ▼ Response in Russian ✓
```

The original user input is restored as the user message for the main request (see the
`before(:request)` callback), so the model receives natural-language context alongside the
instruction to respond in Russian.

## Localization: Translating UI Strings

For agent error messages and other UI text, use the `translate` callable and a locale file.

### 1. Define translations in `config/locales/`:

```yaml
# config/locales/playground.yml
en:
  active_harness:
    support_agent:
      default_error_answer: "Sorry, I can't answer that."
ru:
  active_harness:
    support_agent:
      default_error_answer: "Извините, я не могу ответить на этот вопрос."
```

### 2. Build a translator and pass it at call time:

```ruby
translator = Playground::I18n.translator(locale: :ru)

result = SupportAgent.call(
  input:     input,
  language:  :ru,
  translate: translator,
  context:   {}
)
```

### 3. Use it in the agent DSL via `payload.translate`:

```ruby
default_error_answer ->(payload) {
  payload.translate&.call("active_harness.support_agent.default_error_answer") ||
    "Sorry, I can't answer that."
}
```

`default_error_answer` accepts either a plain String or a callable `(payload) -> String`.
When a callable is given the library calls it with the `Payload` at block time, so you have
full access to `payload.language`, `payload.translate`, and `payload.context`.
