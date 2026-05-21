require_relative "../prompts/compaction_prompt"

class CompactionAgent < ActiveHarness::Agent
  system_prompt CompactionPrompt

  model do
    use      provider: :openrouter, model: "mistralai/mistral-nemo"
    fallback provider: :openrouter, model: "meta-llama/llama-3.3-70b-instruct:free"
  end

  on :retry   do |entry, error| puts "[compaction:retry] #{entry[:model]} — #{error.message}"; end
  on :failure do |attempts|     puts "[compaction:failure] all models failed"; end
end
