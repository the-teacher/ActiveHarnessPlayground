require_relative "../prompts/aggression_prompt"

class AggressionAgent < ActiveHarness::Agent
  system_prompt AggressionPrompt
  format :json

  model do
    use      provider: :openrouter, model: "meta-llama/llama-3.1-8b-instruct"
    fallback provider: :openrouter, model: "mistralai/mistral-nemo"
    fallback provider: :openrouter, model: "meta-llama/llama-3.3-70b-instruct:free"
  end

  on :retry   do |entry, error| puts "[aggression:retry] #{entry[:model]} — #{error.message}"; end
  on :failure do |attempts|     puts "[aggression:failure] all models failed"; end
end
