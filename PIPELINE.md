# ActiveHarness::Pipeline

Pipeline объединяет агентов и трибуналов в последовательную цепочку,
где выход каждого шага становится входом следующего.

---

## Концепции

| Понятие            | Описание                                                                              |
| ------------------ | ------------------------------------------------------------------------------------- |
| **original_input** | Исходный запрос пользователя — никогда не изменяется, хранится до конца               |
| **payload**        | Текущий "активный вход" — передаётся от шага к шагу, transform-шаги меняют его        |
| **context**        | Разделяемый хеш, доступный всем шагам — накапливает метаданные и промежуточные данные |
| **guard step**     | Только проверяет, не меняет payload; может остановить пайплайн                        |
| **transform step** | Меняет payload — `result.output` агента становится новым payload для следующего шага  |
| **tribunal step**  | Параллельная проверка; verdict сохраняется в context, payload не меняется             |

---

## Поток данных

```
Pipeline.new(input: "Wie kann ich...", context: { user_id: 42 })
        │
        │  original_input = "Wie kann ich..."  ← сохраняется навсегда
        │  payload        = "Wie kann ich..."  ← начальное значение
        │  context        = { user_id: 42 }    ← будет пополняться
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Step 1: injection_guard  [GUARD]                                    │
│   получает:  input: payload, context: context                       │
│   payload после: без изменений (guard не трансформирует)            │
│   context после: context[:injection_guard] = result                 │
└─────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Step 2: translate  [TRANSFORM]                                      │
│   получает:  input: payload   ("Wie kann ich...")                   │
│   payload после: result.output  ("How can I configure an agent?")   │
│   context после: context[:translate] = result                       │
└─────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Step 3: compact  [TRANSFORM]                                        │
│   получает:  input: payload   ("How can I configure an agent?")     │
│   payload после: result.output  ("configure agent")                 │
│   context после: context[:compact] = result                         │
└─────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Step 4: safety_tribunal  [TRIBUNAL]                                 │
│   получает:  input: payload   ("configure agent")                   │
│   payload после: без изменений (tribunal не трансформирует)         │
│   context после: context[:safety_tribunal] = tribunal               │
└─────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Step 5: relevance_guard  [GUARD]                                    │
│   получает:  input: payload   ("configure agent")                   │
│   payload после: без изменений                                      │
│   context после: context[:relevance_guard] = result                 │
└─────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Step 6: respond  [TRANSFORM]                                        │
│   получает:  input: payload   ("configure agent")                   │
│   payload после: result.output  ("To configure an agent, ...")      │
│   context после: context[:respond] = result                         │
└─────────────────────────────────────────────────────────────────────┘
        │
        ▼
  pipeline.output         # => "To configure an agent, ..."  (финальный payload)
  pipeline.original_input # => "Wie kann ich..."             (исходный запрос)
  pipeline.context        # => { user_id: 42,
                          #      translate: <Result>,
                          #      compact:   <Result>,
                          #      safety_tribunal: <Tribunal>,
                          #      relevance_guard: <Result>,
                          #      respond:   <Result> }
```

**Правило**: каждый шаг всегда получает `input: payload` (текущее состояние) и `context: context` (общий хеш).
Transform-шаги обновляют payload через `result.output`. Guard и tribunal шаги payload не трогают.

---

## Порядок шагов и обоснование

Порядок выбран по принципу: **безопасность → унификация → токен-экономия → семантика → ответ**.

```
Сырой запрос пользователя
       │
       ▼
1. injection_guard    ← [GUARD]     Безопасность — первый приоритет.
       │                            Проверяет на prompt injection.
       │                            Если обнаружено — стоп, токены не тратятся.
       ▼
2. translate          ← [TRANSFORM] Переводит на английский.
       │                            Все последующие шаги работают с одним языком.
       │                            Ранний перевод дешевле — текст ещё не компактный.
       ▼
3. compact            ← [TRANSFORM] Убирает лишнее, оставляет суть.
       │                            Уменьшает токены ДО дорогих шагов (трибунал, ответ).
       ▼
4. safety_tribunal    ← [TRIBUNAL]  Проверка токсичности и агрессии.
       │                            Работает на компактном английском — экономно.
       │                            Несколько моделей параллельно, коллективное решение.
       ▼
5. relevance_guard    ← [GUARD]     Соответствует ли запрос теме документации?
       │                            Работает на компактном тексте — дёшево.
       ▼
6. respond            ← [TRANSFORM] Основной агент формирует ответ.
                                    Получает чистый, компактный, безопасный, тематический запрос.
```

---

## Предполагаемый интерфейс

### Определение пайплайна

```ruby
class SupportPipeline < ActiveHarness::Pipeline
  # Шаг-guard: проверяет, не меняет payload
  # stop_if: если блок возвращает true — пайплайн останавливается
  step :injection_guard do
    use InjectionGuardAgent
    stop_if ->(result) { result.parsed["detected"] == true }
  end

  # Шаг-transform: выход агента (result.output) становится новым payload
  # Сокращённая форма — когда шаг содержит только агента, без stop_if
  step :translate, TranslationAgent

  # Шаг-transform: компактизация
  step :compact, CompactionAgent

  # Шаг-tribunal: verdict сохраняется в context[:safety_tribunal]
  # payload не меняется
  step :safety_tribunal do
    use SafetyTribunal
    stop_if ->(result) { result.verdict == false }
  end

  # Шаг-guard: проверка релевантности теме
  step :relevance_guard do
    use RelevanceAgent
    stop_if ->(result) { result.parsed["relevant"] == false }
  end

  # Финальный шаг-transform: основной ответ
  # Оба варианта эквивалентны:
  step :respond, SupportAgent
  # step :respond do
  #   use SupportAgent
  # end
end
```

### Запуск

```ruby
pipeline = SupportPipeline.new(
  input:   "Wie kann ich einen Agenten konfigurieren?",
  context: { user_id: 42, language: "German" }
)

pipeline.call

pipeline.output          # => итоговый ответ (nil если остановлен)
pipeline.stopped?         # => false
pipeline.stopped_at       # => nil  (или :safety_tribunal если остановлен там)
pipeline.stop_reason     # => nil  (или объект result шага, где остановился)
pipeline.execution_time  # => 3.42 (секунды, общее время)

# Результаты каждого шага
pipeline.step_results[:translate].output        # => переведённый текст
pipeline.step_results[:compact].output          # => компактный текст
pipeline.step_results[:safety_tribunal].verdict # => true
pipeline.step_results[:respond].output          # => итоговый ответ
```

### Hooks на уровне пайплайна

```ruby
class SupportPipeline < ActiveHarness::Pipeline
  step :injection_guard do
    use InjectionGuardAgent
    stop_if ->(result) { result.parsed["detected"] == true }
  end

  step :translate, TranslationAgent

  step :compact, CompactionAgent

  step :safety_tribunal do
    use SafetyTribunal
    stop_if ->(result) { result.verdict == false }
  end

  step :relevance_guard do
    use RelevanceAgent
    stop_if ->(result) { result.parsed["relevant"] == false }
  end

  step :respond, SupportAgent

  # Глобальные хуки — срабатывают на каждом шаге
  on :before_step do |step_name, payload|
    puts "[pipeline] → #{step_name}: #{payload[0..60]}..."
  end

  on :after_step do |step_name, result|
    puts "[pipeline] ✓ #{step_name} (#{result.execution_time}s)"
  end

  # Хуки на конкретный шаг — срабатывают только для указанного шага
  on :before_step, :translate do |payload|
    puts "[translate] input length: #{payload.length}"
  end

  on :after_step, :translate do |result|
    puts "[translate] → #{result.output}"
  end

  on :before_step, :safety_tribunal do |payload|
    puts "[safety] checking: #{payload}"
  end

  on :after_step, :safety_tribunal do |result|
    puts "[safety] verdict: #{result.verdict}"
  end

  on :stopped do |step_name, result|
    puts "[pipeline] ✗ stopped at #{step_name}"
  end

  on :complete do |result|
    puts "[pipeline] done in #{execution_time}s"
  end
end
```

---

## Что хранит pipeline после вызова

```ruby
pipeline.original_input  # String  — исходный запрос, никогда не меняется
pipeline.output          # String  — payload последнего выполненного шага
pipeline.stopped?        # Boolean — был ли пайплайн остановлен
pipeline.stopped_at      # Symbol  — имя шага где остановился (или nil)
pipeline.stop_reason     # Result  — объект результата шага-останова (или nil)
pipeline.execution_time  # Float   — общее время выполнения в секундах
pipeline.step_results    # Hash    — { step_name => Result/Tribunal }
pipeline.context         # Hash    — итоговый context после всех шагов
```

---

## Структура файлов (playground)

```
app/
  ai/
    agents/
      injection_guard_agent.rb
      translation_agent.rb
      compaction_agent.rb
      relevance_agent.rb
      support_agent.rb
    prompts/
      injection_guard_prompt.rb
      translation_prompt.rb
      compaction_prompt.rb
      relevance_prompt.rb
      support_prompt.rb
    tribunals/
      safety_tribunal.rb       # ToxicityAgent + AggressionAgent
    pipelines/
      support_pipeline.rb
examples/
  08_pipeline.rb
```

---

## Структура файлов (lib)

```
lib/active_harness/
  pipeline.rb          # ActiveHarness::Pipeline — базовый класс
  pipeline/
    step.rb            # ActiveHarness::Pipeline::Step — описание шага
    runner.rb          # логика последовательного выполнения
```
