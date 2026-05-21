# Installation and Setup

## Requirements

- Ruby 2.6+
- Bundler

## Gemfile

```ruby
gem "active_harness", path: "../ActiveHarness"  # local development
# or
gem "active_harness"  # once published to RubyGems
```

Then run:

```bash
bundle install
```

## Configuration

```ruby
require "bundler/setup"
require "active_harness"

ActiveHarness.configure do |config|
  config.openrouter_api_key = ENV["OPENROUTER_API_KEY"]
  config.openai_api_key     = ENV["OPENAI_API_KEY"]

  config.default_temperature = 0.2
  config.default_timeout     = 30

  config.guard_retries = 2   # retry guard up to 2 extra times on bad JSON
  config.debug         = false
end
```

## Environment Variables

Store secrets in `.env` (not committed to git):

```
OPENROUTER_API_KEY=sk-or-...
OPENAI_API_KEY=sk-...
LANGUAGE=en
```

Load them in your entry point:

```ruby
File.readlines(".env").each do |line|
  key, value = line.strip.split("=", 2)
  ENV[key] = value if key && !key.start_with?("#")
end
```

## Project Layout (Recommended)

```
app/
  agents/         # Agent subclasses
  guards/         # Guard subclasses
  prompts/        # Prompt classes (.prompt → String)
  documentation/  # Docs for documentation-aware agents
run.rb            # Entry point
.env              # API keys (gitignored)
```
