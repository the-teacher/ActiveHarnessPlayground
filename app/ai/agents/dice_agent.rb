require_relative "../prompts/dice_prompt"

class DiceAgent < ActiveHarness::Agent
  system_prompt DicePrompt
  format :json

  model do
    use      provider: :openrouter, model: "mistralai/mistral-nemo"
    fallback provider: :openrouter, model: "meta-llama/llama-3.3-70b-instruct:free"
    fallback provider: :openrouter, model: "google/gemma-4-31b-it:free"
  end

  # Roll the dice on setup and store the value in context
  on :setup do
    @context[:dice_roll] = rand(1..6)
    @input = "The dice roll result is #{@context[:dice_roll]}. Is it even?"
  end

  on :retry do |entry, error|
    puts "[retry] #{entry[:provider]}/#{entry[:model]} — #{error.message}"
  end

  on :failure do |attempts|
    puts "[failure] all #{attempts.size} models failed"
  end
end
