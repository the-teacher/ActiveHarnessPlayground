# Run: ruby examples/agents/09_memory.rb

require_relative "../shared"
require_relative "../../app/ai/agents/support_agent"

# ---------------------------------------------------------------------------
# 09 — Conversational memory
#
# Demonstrates Memory with the file adapter.
# Each call to SupportAgent reuses the same Memory object, so the model
# can refer to earlier turns in the conversation.
#
# After running, inspect the JSON file:
#   cat storage/ai/memory/demo_session.json
# ---------------------------------------------------------------------------

header("09 — CONVERSATIONAL MEMORY")

memory = ActiveHarness::Memory.new(
  session_id:   "demo_session",
  depth:        6,
  adapter:      :file,
  path:         File.expand_path("../../storage/ai/memory", __dir__),
  storage_size: 100,
  pretty:       true
)

questions = [
  "What is your return policy?",
  "Does it also apply to accessories?",
  "How long does a refund take?"
]

questions.each_with_index do |q, i|
  puts "\n--- Turn #{i + 1} ---"
  puts "User : #{q}"

  result = SupportAgent.call(
    input:   q,
    memory:  memory,
    context: { language: "English" }
  )

  puts "Agent: #{result.output}"
  puts "Model: #{result.model}"
end

puts "\n--- Memory state after conversation ---"
puts "Turns stored : #{memory.size}"
memory.turns.each_with_index do |t, i|
  puts "  [#{i + 1}] Q: #{t[:request][0..60]}"
  puts "       A: #{t[:response].to_s[0..60]}..."
end

puts "\nJSON file: #{File.join("storage/ai/memory", "demo_session.json")}"
