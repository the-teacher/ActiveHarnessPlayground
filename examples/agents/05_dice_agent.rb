# Run: ruby examples/agents/05_dice_agent.rb

require_relative "../shared"
require_relative "../../app/ai/agents/dice_agent"

# ---------------------------------------------------------------------------
# 05 — Dice agent with structured JSON output
#
# Rolls a dice (1–6) on the Ruby side, sends the value to the LLM,
# and asks it to determine whether the result is even or odd.
#
# The LLM must respond in strict JSON: { "result": true|false, "reason": "..." }
# We parse the response and work with it as a Ruby hash.
# ---------------------------------------------------------------------------

header("05 — DICE AGENT (structured JSON output)")

5.times do |i|
  agent  = DiceAgent.new
  result = agent.call

  roll    = agent.context[:dice_roll]
  parsed  = result.parsed          # Hash — already parsed by the agent
  is_even = parsed["result"]
  reason  = parsed["reason"]

  puts "\nRoll ##{i + 1}: #{roll} — #{is_even ? "EVEN" : "ODD"}"
  puts "Reason : #{reason}"
  puts "Raw    : #{result.output}"
  puts "Model  : #{result.model}"
rescue JSON::ParserError => e
  puts "\nRoll ##{i + 1}: JSON parse error — #{e.message}"
  puts "Raw output: #{result&.output}"
end
