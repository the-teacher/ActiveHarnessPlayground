require_relative "../prompts/translation_prompt"

class TranslationAgent < ActiveHarness::Agent
  system_prompt TranslationPrompt

  model do
    use      provider: :openrouter, model: "mistralai/mistral-nemo"
    fallback provider: :openrouter, model: "meta-llama/llama-3.3-70b-instruct:free"
  end

  on :retry   do |entry, error| puts "[translation:retry] #{entry[:model]} — #{error.message}"; end
  on :failure do |attempts|     puts "[translation:failure] all models failed"; end
end
