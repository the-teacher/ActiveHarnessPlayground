# Run: ruby examples/agents/14_custom_memory.rb

require_relative "../shared"
require_relative "../../app/ai/agents/support_agent"
require_relative "../../app/ai/memory/app_memory"

# ---------------------------------------------------------------------------
# 14 — Custom memory class
#
# Instead of constructing ActiveHarness::Memory with all options inline,
# we define AppMemory once (app/ai/memory/app_memory.rb) and instantiate
# it with just a session_id everywhere in the codebase.
#
# After running, inspect the JSON file:
#   cat storage/ai/memory/custom_memory_demo.json
# ---------------------------------------------------------------------------

header("14 — CUSTOM MEMORY CLASS")

memory = AppMemory.new(session_id: "custom_memory_demo")
memory.delete rescue nil  # start clean

agent = SupportAgent.new(context: { language: "English" }, memory: memory)

questions = [
  "What is your return policy?",
  "Does that also apply to digital products?",
  "How long does a refund usually take?"
]

questions.each_with_index do |question, i|
  puts "\n[#{i + 1}] You: #{question}"
  result = agent.call(question)
  puts "     AI : #{result.output}"
  puts "     via: #{result.model} (#{result.execution_time}s)"
end

section("Memory state")
puts "Session  : #{memory.session_id}"
puts "Turns    : #{memory.size}"
puts "Storage  : #{AppMemory::STORAGE_PATH}/#{memory.session_id}.json"
memory.turns.each_with_index do |t, i|
  puts "  [#{i + 1}] #{t[:role]}: #{t[:content].to_s.gsub(/\s+/, " ")[0..60]}"
end
