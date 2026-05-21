require_relative "../prompts/relevance_prompt"

class RelevanceAgent < ActiveHarness::Agent
  system_prompt RelevancePrompt
  format :json

  model do
    use      provider: :openrouter, model: "mistralai/mistral-nemo"
    fallback provider: :openrouter, model: "meta-llama/llama-3.3-70b-instruct:free"
  end

  on :retry   do |entry, error| puts "[relevance:retry] #{entry[:model]} — #{error.message}"; end
  on :failure do |attempts|     puts "[relevance:failure] all models failed"; end
end
