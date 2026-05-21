require_relative "../prompts/toxicity_prompt"

class ToxicityAgent < ActiveHarness::Agent
  system_prompt ToxicityPrompt
  format :json

  model do
    use      provider: :openrouter, model: "meta-llama/llama-3.1-8b-instruct"
    fallback provider: :openrouter, model: "mistralai/mistral-nemo"
    fallback provider: :openrouter, model: "meta-llama/llama-3.3-70b-instruct:free"
  end

  on :retry   do |entry, error| puts "[toxicity:retry] #{entry[:model]} — #{error.message}"; end
  on :failure do |attempts|     puts "[toxicity:failure] all models failed"; end
end
