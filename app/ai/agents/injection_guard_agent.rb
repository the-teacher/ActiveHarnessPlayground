require_relative "../prompts/injection_guard_prompt"

class InjectionGuardAgent < ActiveHarness::Agent
  system_prompt InjectionGuardPrompt
  format :json

  model do
    use      provider: :openrouter, model: "meta-llama/llama-3.1-8b-instruct"
    fallback provider: :openrouter, model: "mistralai/mistral-nemo"
    fallback provider: :openrouter, model: "meta-llama/llama-3.3-70b-instruct:free"
  end

  on :retry   do |entry, error| puts "[injection_guard:retry] #{entry[:model]} — #{error.message}"; end
  on :failure do |attempts|     puts "[injection_guard:failure] all models failed"; end
end
