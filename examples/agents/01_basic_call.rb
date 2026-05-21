# Run: ruby examples/agents/01_basic_call.rb

require_relative "../shared"

# ---------------------------------------------------------------------------
# 01 — Basic single agent call
#
# Creates one agent instance and calls it.
# Prints the full Result struct fields.
# ---------------------------------------------------------------------------

header("01 — BASIC SINGLE CALL")

agent  = SupportAgent.new(input: "What is USA capital?", context: { language: "Russian" })
result = agent.call

puts "\nProvider      : #{result.provider}"
puts "Model         : #{result.model}"
puts "Temperature   : #{result.temperature || "n/a"}"
puts "System Prompt : #{result.system_prompt}"
puts "Input         : #{result.input}"
puts "Output        : #{result.output}"
puts "Model List    :"
puts result.model_list.map { |m| "  => #{m[:provider]}/#{m[:model]} (temperature: #{m[:temperature] || "n/a"})" }.join("\n")
if result.usage
  puts "Usage         :"
  puts "  input_tokens  : #{result.usage[:input_tokens]}"
  puts "  output_tokens : #{result.usage[:output_tokens]}"
  puts "  total_tokens  : #{result.usage[:total_tokens]}"
end
