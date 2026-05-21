# Run: ruby examples/agents/04_override_models.rb

require_relative "../shared"

# ---------------------------------------------------------------------------
# 04 — Override models at instantiation time
#
# The class defines its own model chain via `model do...end`.
# Passing `models:` to the constructor replaces that chain for this instance
# only — without touching the class definition.
#
# Useful when you want to:
#   - A/B test a different model for a subset of requests
#   - Route premium users to a faster / more capable model
#   - Pin a specific model version in tests
# ---------------------------------------------------------------------------

header("04 — OVERRIDE MODELS via constructor")

puts "\n--- Default model chain (from class definition) ---"
default_agent = SupportAgent.new(input: "What is USA capital?", context: { language: "Russian" })
default_result = default_agent.call

puts "Model  : #{default_result.model}"
puts "Output : #{default_result.output}"
puts "Chain  :"
puts default_result.model_list.map { |m| "  => #{m[:provider]}/#{m[:model]}" }.join("\n")

puts "\n--- Overridden model chain (passed via constructor) ---"
custom_agent = SupportAgent.new(
  input:   "What is USA capital?",
  context: { language: "French" },
  models:  [
    { provider: :openrouter, model: "mistralai/mistral-nemo", temperature: 0.9 },
    { provider: :openrouter, model: "meta-llama/llama-3.3-70b-instruct:free" }
  ]
)
custom_result = custom_agent.call

puts "Model  : #{custom_result.model}"
puts "Output : #{custom_result.output}"
puts "Chain  :"
puts custom_result.model_list.map { |m| "  => #{m[:provider]}/#{m[:model]} (temperature: #{m[:temperature] || "n/a"})" }.join("\n")
