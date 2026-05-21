require_relative "../agents/politeness_agent"

class PolitenessTribunal < ActiveHarness::Tribunal
  def initialize(input:)
    model_1 = [{ provider: :openrouter, model: "mistralai/mistral-nemo" }]
    model_2 = [{ provider: :openrouter, model: "meta-llama/llama-3.1-8b-instruct" }]

    super(
      input:  input,
      agents: [
        PolitenessAgent.new(models: model_1),
        PolitenessAgent.new(models: model_2),
      ]
    )
  end

  # Define the VERDICT logic.
  process do |results|
    results.all? do |result|
      result.parsed["result"] == true
    end
  end
end

