# Run: ruby examples/agents/12_fallback_on_error.rb

require_relative "../shared"

# ---------------------------------------------------------------------------
# 12 — Bogus first model: retry + fallback to the next working model
#
# InvalidRequestError (including "not a valid model ID") is RETRYABLE.
# A non-existent or broken model does NOT abort the chain:
# the :retry hook records the error and execution moves to the next model.
# The chain succeeds as soon as any model responds.
#
# STOP_ERRORS (abort the chain immediately):
#   InvalidApiKeyError  — the key is wrong for every model, retrying is pointless
#   SafetyBlockedError  — the input itself is blocked, another model won't help
# ---------------------------------------------------------------------------

header("12 -- Bogus first model => retry => fallback works")

agent = SupportAgent.new(
  input:   "What is the capital of France?",
  context: { language: "English" },
  models:  [
    # [0] Non-existent model => InvalidRequestError (RETRYABLE) => advance to next
    { provider: :openrouter, model: "fake-provider/this-model-does-not-exist-xyz" },
    # [1] Another bogus name — shows the chain keeps going
    { provider: :openrouter, model: "another/bogus-model-xyz" },
    # [2..] Real free models (may be rate-limited)
    { provider: :openrouter, model: "meta-llama/llama-3.3-70b-instruct:free" },
    { provider: :openrouter, model: "google/gemma-4-31b-it:free" },
    # [4] Cheap paid model as a reliable final fallback
    { provider: :openrouter, model: "mistralai/mistral-nemo", temperature: 0.5 }
  ]
)

puts "\nModel chain:"
agent.models.to_a.each_with_index do |m, i|
  puts "  [#{i}] #{m[:provider]}/#{m[:model]}"
end

puts "\nCalling agent..."
begin
  agent.call
  result = agent.result
  puts "\n[SUCCESS]"
  puts "  Model used : #{result.model}"
  puts "  Provider   : #{result.provider}"
  puts "  Output     : #{result.output}"
rescue ActiveHarness::Errors::AllModelsFailed => e
  puts "\n[AllModelsFailed] all models in chain failed:"
  puts e.message
rescue => e
  puts "\n[#{e.class}] #{e.message}"
end