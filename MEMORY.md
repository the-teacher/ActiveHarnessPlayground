# ActiveHarness::Memory

Этот документ описывает дизайн памяти для агентов в ActiveHarness2:
что это такое, как она работает на уровне протокола LLM,
и конкретную архитектуру реализации.

> Речь только об агентах. Память в пайплайнах и трибуналах — отдельная тема.

---

## Ключевой принцип

**Memory — это только хранилище истории.**

Память записывает пары запрос/ответ и хранит их на диске (или в Redis/БД).
Она **не вставляет историю в LLM автоматически**.

Как и когда использовать историю в запросе — решает разработчик.
Инжекция происходит вручную: через хуки агента или через класс системного промпта.

Это намеренное решение — чтобы у разработчика был полный контроль над тем,
что попадает в контекст модели, в каком формате и в каком объёме.

---

## Что такое память?

Языковая модель stateless — она не помнит ни одного предыдущего запроса.
Каждый вызов API — чистый лист.

**Память** — это способ передать модели артефакты прошлых взаимодействий,
чтобы она могла учитывать их при формировании ответа.

На уровне API это означает передачу массива сообщений `messages`
с историей диалога вместо одного пользовательского сообщения.

Сейчас `build_messages` в `agent/providers.rb` формирует:

```
[ { role: "system", content: "..." },
  { role: "user",   content: "<текущий input>" } ]
```

С памятью (глубина 2 прошлых обмена) это становится:

```
[ { role: "system",    content: "..." },
  { role: "user",      content: "Я хочу вернуть товар"  },   ← turn -2
  { role: "assistant", content: "Подскажите номер заказа." },
  { role: "user",      content: "Заказ #4521"             },   ← turn -1
  { role: "assistant", content: "Нашёл. Причина?"         },
  { role: "user",      content: "Он сломан"               } ]  ← текущий input
```

Модель видит весь разговор и отвечает с учётом контекста.

---

## Дизайн: объект `Memory`

### Обзор

```
Memory.new(session_id:, depth:, adapter:, **adapter_opts)
       │
       ├── знает session_id
       ├── знает depth — сколько прошлых turns передавать в LLM
       ├── держит список turns в RAM
       └── делегирует персистентность в адаптер
```

### Конструктор

```ruby
memory = ActiveHarness::Memory.new(
  session_id:       "user_42_session_7",  # обязательно
  depth:            10,                    # сколько последних turns передавать модели
  adapter:          :file,                 # :file (умолчание), :redis, :db, или класс
  path:             "storage/ai/memory",  # опция для файлового адаптера (умолчание)
  storage_size:     1000,                  # максимальное кол-во turns в хранилище
  eviction_percent: 10,                    # % старых записей для удаления при достижении лимита
  read_only:        false,                 # только чтение, без записи новых turns
  enabled:          true,                  # false — отключить память полностью
  namespace:        nil,                   # изолировать историю по агенту внутри сессии
  on_trim:         nil,                   # proc — вызывается со списком удалённых turns при очистке
  async:            false                  # асинхронная запись в адаптер (не блокирует ответ)
)
```

| Параметр           | Тип            | По умолчанию          | Описание                                                |
| ------------------ | -------------- | --------------------- | ------------------------------------------------------- |
| `session_id`       | String         | обязательно           | Идентификатор сессии/пользователя                       |
| `depth`            | Integer        | `nil` (всё)           | Сколько последних turns отдавать модели                 |
| `adapter`          | Symbol / Class | `:file`               | Тип хранилища                                           |
| `path`             | String         | `"storage/ai/memory"` | Базовый путь (только для `:file`)                       |
| `compact`          | Boolean        | `false`               | Компактный формат хранения (q/a вместо полной записи)   |
| `storage_size`     | Integer        | `1000`                | Максимальное число turns в хранилище (nil = без лимита) |
| `eviction_percent` | Integer        | `10`                  | % старых turns, удаляемых при достижении `storage_size` |
| `read_only`        | Boolean        | `false`               | Только читать историю, не записывать новые turns        |
| `enabled`          | Boolean        | `true`                | `false` — отключить память полностью (read + write)     |
| `namespace`        | String / nil   | `nil`                 | Изолировать историю агента внутри одной сессии          |
| `on_trim`          | Proc / nil     | `nil`                 | Callback при очистке старых turns: `->(turns) { ... }`  |
| `async`            | Boolean        | `false`               | Асинхронная запись в адаптер (не блокирует ответ)       |

---

## Формат хранения

### Полный формат (по умолчанию)

Каждый turn содержит запрос, ответ, метаданные.
Файл: `storage/ai/memory/<session_id>.json`

```json
{
  "session_id": "user_42_session_7",
  "turns": [
    {
      "request": "Привет",
      "response": "Здравствуйте! Чем могу помочь?",
      "agent": "SupportAgent",
      "model": "mistralai/mistral-nemo",
      "at": "2026-05-11T10:05:00Z"
    },
    {
      "request": "Я хочу вернуть товар",
      "response": "Подскажите номер заказа.",
      "agent": "SupportAgent",
      "model": "mistralai/mistral-nemo",
      "at": "2026-05-11T10:05:42Z"
    }
  ]
}
```

### Компактный формат (`compact: true`)

Только запрос и ответ — минимальный размер файла.

```json
{
  "session_id": "user_42_session_7",
  "turns": [
    { "q": "Привет", "a": "Здравствуйте! Чем могу помочь?" },
    { "q": "Я хочу вернуть товар", "a": "Подскажите номер заказа." }
  ]
}
```

Компактный формат удобен когда запись происходит через хук и
данные вручную формируются пользователем:

```ruby
on :after_call do |result|
  @memory&.record(
    request:  @input,
    response: result.output
    # без agent/model/at — компактно
  )
end
```

---

## Интерфейс адаптера

Любой адаптер реализует четыре метода:

```ruby
adapter.open(session_id)   # загрузить данные сессии (из файла / Redis / DB)
adapter.read               # вернуть массив turns [{ request:, response:, ... }]
adapter.write(turn)        # записать один turn (немедленно или буферизовать)
adapter.close              # сбросить буфер / закрыть соединение
```

### Файловый адаптер (`:file`) — по умолчанию

```
storage/ai/memory/
  user_42_session_7.json
  user_99_session_1.json
  ...
```

Параметры, доступные для кастомизации:

| Параметр           | Описание                                            | По умолчанию          |
| ------------------ | --------------------------------------------------- | --------------------- |
| `path`             | Директория для хранения файлов                      | `"storage/ai/memory"` |
| `filename`         | Proc или String. По умолчанию `"<session_id>.json"` | `nil` (авто)          |
| `pretty`           | Форматированный JSON (для отладки)                  | `false`               |
| `compact`          | Хранить только `q/a` без метаданных                 | `false`               |
| `encoding`         | Кодировка файла                                     | `"UTF-8"`             |
| `storage_size`     | Максимальное число turns в файле                    | `1000`                |
| `eviction_percent` | % старых turns, удаляемых при вытеснении            | `10`                  |

Пример с кастомным именем файла:

```ruby
ActiveHarness::Memory.new(
  session_id: "u42",
  adapter:    :file,
  path:       "tmp/conversations",
  filename:   ->(sid) { "chat_#{sid}_#{Date.today}.json" },
  pretty:     true
)
```

### Redis-адаптер (`:redis`)

```ruby
ActiveHarness::Memory.new(
  session_id: "u42",
  adapter:    :redis,
  url:        "redis://localhost:6379/0",  # или REDIS_URL из ENV
  ttl:        60 * 60 * 24 * 7            # 7 дней, nil — без истечения
)
```

Ключ в Redis: `"active_harness:memory:<session_id>"`

Параметры:

| Параметр     | Описание                           | По умолчанию               |
| ------------ | ---------------------------------- | -------------------------- |
| `url`        | URL подключения                    | `ENV["REDIS_URL"]`         |
| `key_prefix` | Префикс ключа                      | `"active_harness:memory:"` |
| `ttl`        | Время жизни в секундах (`nil` = ∞) | `nil`                      |

### Database-адаптер (`:db`)

```ruby
ActiveHarness::Memory.new(
  session_id: "u42",
  adapter:    :db,
  connection: ActiveRecord::Base.connection,  # или Sequel::Database
  table:      "agent_memory_turns"
)
```

Минимальная схема таблицы:

```sql
CREATE TABLE agent_memory_turns (
  id         SERIAL PRIMARY KEY,
  session_id VARCHAR NOT NULL,
  request    TEXT NOT NULL,
  response   TEXT NOT NULL,
  agent      VARCHAR,
  model      VARCHAR,
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX ON agent_memory_turns (session_id);
```

### Пользовательский адаптер

Передаётся объект, реализующий контракт `open / read / write / close`:

```ruby
class MyS3Adapter
  def open(session_id)
    @session_id = session_id
    @turns      = download_from_s3(session_id)
  end

  def read
    @turns.dup
  end

  def write(turn)
    @turns << turn
    upload_to_s3(@session_id, @turns)  # немедленно или буферизовать
  end

  def close
    # при необходимости финальный flush
  end
end

ActiveHarness::Memory.new(
  session_id: "u42",
  adapter:    MyS3Adapter.new
)
```

---

## API объекта `Memory`

```ruby
memory = ActiveHarness::Memory.new(session_id: "u42", depth: 5)

# Загрузить историю из хранилища (вызывается автоматически при передаче агенту)
memory.load

# Записать turn (вызывается в хуке after_call)
memory.record(
  request:  "Я хочу вернуть товар",
  response: "Подскажите номер заказа.",
  agent:    "SupportAgent",
  model:    "mistralai/mistral-nemo"
)

# Получить последние N turns для передачи в LLM (с учётом depth)
memory.to_messages
# => [
#      { role: "user",      content: "..." },
#      { role: "assistant", content: "..." },
#      ...
#    ]

# Весь список turns (без обрезки по depth)
memory.turns
# => [{ request:, response:, agent:, model:, at: }, ...]

# Закрыть / сбросить буфер адаптера
memory.close

# Очистить память сессии (не удаляет файл/ключ)
memory.clear

# Удалить всю сессию из хранилища (файл / ключ Redis / строки в БД)
memory.delete

# Количество turns в памяти
memory.size

# Получить сообщения с фильтром по агенту
memory.to_messages(filter: ->(turn) { turn[:agent] == "SupportAgent" })

# Получить сообщения за последний час
memory.to_messages(since: Time.now - 3600)
```

---

## Ограничение размера хранилища и вытеснение

`storage_size` задаёт максимальное количество turns, которое адаптер хранит на диске / в Redis / в БД.
Ограничение применяется **к хранилищу** (персистентный слой), а не к `depth` (что передаётся в LLM).

### Механизм вытеснения (eviction)

Когда при вызове `adapter.write(turn)` количество хранимых turns достигает `storage_size`,
адаптер удаляет самые старые записи — `eviction_percent` % от общего числа — и только
затем добавляет новый turn.

```
storage_size = 1000, eviction_percent = 10

turns = 1000  →  удалить первые 100 (10%)  →  записать новый  →  turns = 901
```

Параметры:

| Параметр           | Тип     | По умолчанию | Описание                                                    |
| ------------------ | ------- | ------------ | ----------------------------------------------------------- |
| `storage_size`     | Integer | `1000`       | Максимум turns в хранилище (`nil` — без ограничения)        |
| `eviction_percent` | Integer | `10`         | Сколько % старых turns удалять при достижении лимита (1–50) |

Пример с агрессивной очисткой (5%):

```ruby
ActiveHarness::Memory.new(
  session_id:       "u42",
  storage_size:     500,
  eviction_percent: 5    # удалять 25 записей при достижении 500
)
```

Пример с мягкой очисткой (20%):

```ruby
ActiveHarness::Memory.new(
  session_id:       "u42",
  storage_size:     2000,
  eviction_percent: 20   # удалять 400 записей при достижении 2000
)
```

> **Заметка:** `storage_size` и `depth` — независимые параметры.
> `depth: 10` означает «передавать последние 10 turns в LLM».
> `storage_size: 1000` означает «хранить не более 1000 turns на диске».
> Вы можете хранить 1000 turns, но передавать в модель только последние 10.

---

## Дополнительные параметры

### `read_only` — только чтение

Загружает историю из хранилища, но игнорирует вызовы `memory.record`.
Полезно когда агент читает чужую сессию, не изменяя её.

```ruby
memory = ActiveHarness::Memory.new(session_id: "u42", read_only: true)
# история загружается и передаётся в LLM, но новые turns не записываются
```

---

### `enabled` — отключить память

Полностью исключает память из цикла агента без удаления объекта из кода.
Удобно при тестировании или A/B-экспериментах.

```ruby
memory = ActiveHarness::Memory.new(
  session_id: "u42",
  enabled:    !test_env?   # в тестах память отключена
)
```

---

### `namespace` — изоляция агентов внутри сессии

Когда одну сессию используют разные агенты, их истории хранятся отдельно.
Без `namespace` все агенты пишут в один файл/ключ.

```ruby
memory = ActiveHarness::Memory.new(
  session_id: "user_42",
  namespace:  "SupportAgent"
)
```

Без `namespace`:

```
storage/ai/memory/user_42.json           ← все агенты пишут сюда
```

С `namespace`:

```
storage/ai/memory/user_42/SupportAgent.json
storage/ai/memory/user_42/TranslationAgent.json
```

---

### `on_trim` — callback при очистке истории

Вызывается со списком удалённых turns каждый раз, когда срабатывает очистка.
Можно использовать для архивации, логирования или суммаризации.

```ruby
memory = ActiveHarness::Memory.new(
  session_id:   "u42",
  storage_size: 100,
  on_trim: ->(evicted_turns) {
    ArchiveStore.save(session_id: "u42", turns: evicted_turns)
    puts "Evicted #{evicted_turns.size} turns"
  }
)
```

---

### `async` — асинхронная запись

Запись в адаптер происходит в фоне и не блокирует возврат результата агенту.
Подходит когда latency важнее гарантии немедленной персистентности.

```ruby
memory = ActiveHarness::Memory.new(session_id: "u42", async: true)
# result возвращается немедленно, запись в файл — в фоне
```

> **Важно:** `async: true` несовместим с ситуациями, где следующий вызов агента
> должен гарантированно видеть только что записанный turn.

## Инжекция истории в LLM — вручную

После `memory.load` история доступна через `@memory.to_messages` или `@memory.turns`.
Как именно подать её модели — выбор разработчика.

### Вариант A: через хук `before_call` — добавить историю к `@input`

```ruby
class SupportAgent < ActiveHarness::Agent
  on :before_call do
    history = @memory&.to_messages
    if history&.any?
      lines  = history.map { |m| "#{m[:role]}: #{m[:content]}" }.join("\n")
      @input = "Previous conversation:\n#{lines}\n\nUser: #{@input}"
    end
  end
end
```

### Вариант B: через хук `after_system_prompt` — добавить историю в промпт

```ruby
class SupportAgent < ActiveHarness::Agent
  on :after_system_prompt do |prompt|
    history = @memory&.to_messages
    if history&.any?
      lines          = history.map { |m| "#{m[:role]}: #{m[:content]}" }.join("\n")
      @system_prompt = "#{prompt}\n\nConversation so far:\n#{lines}"
    end
  end
end
```

### Вариант C: через класс системного промпта

```ruby
class SupportPrompt
  def call
    # @memory инжектируется агентом вместе с @input и @context
    base = "You are a helpful support assistant."
    return base unless @memory&.size&.positive?

    history = @memory.to_messages
                     .map { |m| "#{m[:role]}: #{m[:content]}" }
                     .join("\n")
    "#{base}\n\nConversation so far:\n#{history}"
  end
end

class SupportAgent < ActiveHarness::Agent
  system_prompt SupportPrompt
end
```

> Все три варианта работают. Выбор зависит от того, где удобнее держать логику:
> в самом агенте (хуки) или в классе промпта.

---

## Запись истории — автоматически

После успешного LLM-вызова агент **автоматически** записывает turn в память:

```ruby
memory.record(
  request:  @input,
  response: result.output,
  agent:    self.class.name,
  model:    result.model
)
```

Если нужен другой формат (компактный, с доп. полями) — переопределите в хуке `after_call`:

```ruby
class SupportAgent < ActiveHarness::Agent
  on :after_call do |result|
    @memory&.record(
      request:  @input,
      response: result.output
      # без agent/model — компактнее
    )
  end
end
```

При наличии хука `after_call` — запись происходит и автоматически (до хука), и в хуке.
Если нужна только одна запись — установите `read_only: false` и управляйте вручную,
либо просто не дублируйте вызов `memory.record` в хуке.

### Через параметр `memory:`

```ruby
memory = ActiveHarness::Memory.new(session_id: "user_42", depth: 8)

result = SupportAgent.call(
  input:  "Я хочу вернуть товар",
  memory: memory
)
```

Внутри агента `@memory` становится доступен во всех хуках.

### Через `context[:memory]`

Если `memory:` не передан напрямую, агент проверяет `context[:memory]`:

```ruby
ctx = { user_id: 42, memory: memory }

result = SupportAgent.call(input: "...", context: ctx)
```

Это удобно в пайплайнах, где `context` передаётся через все шаги
и каждый агент сам находит память.

---

## Жизненный цикл в агенте

```
Agent.call(input:, memory:)
      │
      ├── setup hook
      │
      ├── memory.load          ← загружает историю из адаптера в RAM
      │
      ├── resolve_system_prompt
      │     └── (здесь можно вручную читать @memory и вставлять в промпт)
      │
      ├── before_call hook
      │     └── (здесь можно вручную читать @memory и вставлять в @input)
      │
      ├── build_messages       ← system prompt + текущий input (без истории)
      │
      ├── LLM call
      │
      ├── save_to_memory       ← автоматически записывает turn в адаптер
      │
      ├── after_call hook
      │
      └── return result
```

> История НЕ вставляется в `build_messages` автоматически.
> Агент загружает её в RAM (`memory.load`), но инжекция — на стороне разработчика.

---

## Thread Safety

Объект `Memory` **не потокобезопасен** для concurrent use.
Если несколько потоков или файберов используют один объект `Memory` одновременно,
in-RAM список turns может повредиться.

**Правило:** создавайте отдельный объект `Memory` на каждый поток / HTTP-запрос / файбер.

```ruby
# Правильно — каждый запрос получает свой объект
def handle_request(session_id, input)
  memory = ActiveHarness::Memory.new(session_id: session_id, depth: 8)
  SupportAgent.call(input: input, memory: memory)
end

# Неправильно — один shared объект на весь процесс
MEMORY = ActiveHarness::Memory.new(session_id: "shared")  # ← опасно в многопоточной среде
```

---

## Пример: полный сценарий

```ruby
# Создаём память для сессии пользователя
memory = ActiveHarness::Memory.new(
  session_id: "user_42_chat_9",
  depth:      6,              # последние 6 turns = 12 сообщений
  adapter:    :file,
  path:       "storage/ai/memory"
)

# Первый запрос — память пустая
result1 = SupportAgent.call(
  input:   "Какова ваша политика возврата?",
  memory:  memory,
  context: { language: "ru" }
)
# → LLM видит только system prompt + "Какова ваша политика возврата?"
# → память пустая — историю инжектировать нечего
# → после ответа: memory автоматически записывает turn в storage/ai/memory/user_42_chat_9.json

# Второй запрос — память содержит 1 turn
result2 = SupportAgent.call(
  input:   "А на аксессуары тоже распространяется?",
  memory:  memory,
  context: { language: "ru" }
)
# → LLM видит только system prompt + второй вопрос
# → если нужна история — добавьте хук before_call или after_system_prompt (см. выше)

# Файл storage/ai/memory/user_42_chat_9.json после двух вызовов:
# {
#   "session_id": "user_42_chat_9",
#   "turns": [
#     { "request": "Какова ваша политика возврата?",
#       "response": "...",
#       "agent": "SupportAgent",
#       "model": "mistralai/mistral-nemo",
#       "at": "2026-05-11T10:05:00Z" },
#     { "request": "А на аксессуары тоже?",
#       "response": "...",
#       "agent": "SupportAgent",
#       "model": "mistralai/mistral-nemo",
#       "at": "2026-05-11T10:05:38Z" }
#   ]
# }
```

---

## Что можно кастомизировать

| Уровень       | Параметр / метод        | Что контролирует                                           |
| ------------- | ----------------------- | ---------------------------------------------------------- |
| Memory        | `depth`                 | Сколько прошлых turns передавать в LLM                     |
| Memory        | `storage_size`          | Максимальное число turns в хранилище (nil = без лимита)    |
| Memory        | `eviction_percent`      | % старых turns для удаления при достижении `storage_size`  |
| Memory        | `compact`               | Полный или сжатый формат записи                            |
| Memory        | `adapter`               | Тип хранилища: file / redis / db / свой класс              |
| File adapter  | `path`                  | Директория хранения                                        |
| File adapter  | `filename`              | Шаблон имени файла (String или Proc)                       |
| File adapter  | `pretty`                | Форматированный JSON (удобно при отладке)                  |
| Redis adapter | `key_prefix`            | Префикс ключа в Redis                                      |
| Redis adapter | `ttl`                   | Время жизни записи                                         |
| DB adapter    | `table`                 | Имя таблицы                                                |
| DB adapter    | `connection`            | Объект соединения (ActiveRecord, Sequel, Pg, ...)          |
| Свой адаптер  | `open/read/write/close` | Полный контроль над логикой хранения                       |
| Agent hook    | `on :after_call`        | Когда и что именно записывать в память                     |
| Agent hook    | `on :setup`             | Предобработка / замена памяти в зависимости от контекста   |
| Memory        | `read_only`             | Запретить запись, оставить только чтение истории           |
| Memory        | `enabled`               | Полностью отключить память (no-op для read и write)        |
| Memory        | `namespace`             | Изолировать историю по агенту внутри одной сессии          |
| Memory        | `on_trim`               | Callback при очистке старых turns: архивация, суммаризация |
| Memory        | `async`                 | Асинхронная запись, не блокирует ответ агента              |

---

## Что НЕ является памятью

| Артефакт            | Это памятью? | Почему                                         |
| ------------------- | ------------ | ---------------------------------------------- |
| `context` hash      | Частично     | Хранит факты и флаги, но не историю диалога    |
| `system_prompt`     | Нет          | Статические инструкции, не прошлые ответы      |
| `result.output`     | Нет          | Один ответ, не структура для переиспользования |
| `attempts` в Result | Нет          | Технические метаданные о попытках вызова       |

---

## Структура файлов

```
lib/
  active_harness/
    memory.rb                   ← объект Memory (публичный API)
    memory/
      adapter/
        base.rb                 ← контракт open/read/write/close
        file.rb                 ← JSON-файловый адаптер (по умолчанию)
        redis.rb                ← Redis-адаптер
        db.rb                   ← Database-адаптер

storage/ai/memory/                  ← файлы сессий по умолчанию
  user_42_session_7.json
  user_99_session_1.json
```

---

## Стратегия суммаризации (будущее направление)

Когда история диалога становится очень длинной и превышает `context window` модели,
простого обрезания по `depth` недостаточно — теряется важный контекст начала разговора.

Решение — **суммаризация**: вытесненные turns передаются агенту-суммаризатору,
который сжимает их в короткий текст. Summary включается в начало как системное сообщение.

```
[turn_1..turn_20, вытеснены]  →  SummaryAgent  →  "Пользователь вернул товар из заказа #4521,
                                                    сломан при доставке, оформлен возврат"
                                      ↓
                              включить в system prompt
                                      ↓
[turn_21, turn_22, ...]  — продолжение с контекстом начала разговора
```

Это интегрируется через `on_trim`:

```ruby
memory = ActiveHarness::Memory.new(
  session_id: "u42",
  depth:      10,
  on_trim: ->(evicted_turns) {
    text    = evicted_turns.map { |t| "Q: #{t[:request]}\nA: #{t[:response]}" }.join("\n\n")
    summary = SummaryAgent.call(input: text).output
    memory.prepend_system_note(summary)  # гипотетический API
  }
)
```

> Это отдельная большая задача. Описана здесь как направление для проработки.

---

## Следующие шаги

1. ~~Реализовать `Memory` и `Adapter::Base` контракт~~ ✓
2. ~~Реализовать `Adapter::File` (JSON) с поддержкой `namespace`~~ ✓
3. ~~Расширить `Agent#call` сигнатурой `memory:`~~ ✓
4. ~~Добавить автоматическое сохранение в ядро (после LLM-вызова)~~ ✓
5. Реализовать `Adapter::Redis` и `Adapter::DB`
6. Реализовать `read_only`, `enabled`, `async`, `on_trim` в `Memory`
7. Реализовать `memory.to_messages(filter:, since:)` и `memory.delete`
8. Добавить тесты
9. Проработать стратегию суммаризации
