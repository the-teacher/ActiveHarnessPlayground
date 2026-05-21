require_relative "../prompts/politeness_prompt"

class PolitenessAgent < ActiveHarness::Agent
  system_prompt PolitenessPrompt
  format :json

  model do
    use      provider: :openrouter, model: "mistralai/mistral-nemo"
    fallback provider: :openrouter, model: "meta-llama/llama-3.3-70b-instruct:free"
  end

  on :retry   do |entry, error| puts "[politeness:retry] #{entry[:model]} — #{error.message}"; end
  on :failure do |attempts|     puts "[politeness:failure] all models failed"; end
end
