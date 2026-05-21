require_relative "../agents/politeness_agent"
require_relative "../agents/constructiveness_agent"

class ContentQualityTribunal < ActiveHarness::Tribunal
  agents PolitenessAgent, ConstructivenessAgent

  on(:before_call)    {           puts "[tribunal] starting" }
  on(:after_agent)    { |result|  puts "[tribunal] agent done — model: #{result.model}, result: #{result.parsed["result"].inspect}" }
  on(:agent_error)    { |name, e| puts "[tribunal] agent failed — #{name}: #{e.message}" }
  on(:before_verdict) { |results| puts "[tribunal] computing verdict over #{results.size} result(s)"; results }
  on(:after_verdict)  { |verdict| puts "[tribunal] verdict: #{verdict.inspect}" }

  process do |results|
    results.all? { |r| r.parsed["result"] == true }
  end
end
