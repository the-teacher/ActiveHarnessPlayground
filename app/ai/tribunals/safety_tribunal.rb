require_relative "../agents/toxicity_agent"
require_relative "../agents/aggression_agent"

# Runs ToxicityAgent and AggressionAgent in parallel.
# Verdict is true (safe) only when neither flags a problem.
class SafetyTribunal < ActiveHarness::Tribunal
  agents ToxicityAgent, AggressionAgent

  on(:after_agent)  { |result|  puts "[safety_tribunal] agent done — model: #{result.model}, toxic: #{result.parsed["toxic"].inspect}, aggressive: #{result.parsed["aggressive"].inspect}" }
  on(:agent_error)  { |name, e| puts "[safety_tribunal] agent failed — #{name}: #{e.message}" }

  process do |results|
    results.none? { |r| r.parsed["toxic"] == true || r.parsed["aggressive"] == true }
  end
end
