# Run: ruby examples/agents/11_mini_chat.rb

require_relative "../shared"

# ---------------------------------------------------------------------------
# 11 — Mini chat: one agent, many inputs
#
# Three ways to set input after instantiation:
#
#   agent.input = "..."           # direct setter
#   agent.call("...")             # inline — sets input and calls
#   result = agent.call           # reuses last input
# ---------------------------------------------------------------------------

header("11 — MINI CHAT")

memory = ActiveHarness::Memory.new(
  session_id: "mini_chat",
  depth:      10,
  adapter:    :file,
  path:       File.join(__dir__, "../../storage/ai/memory"),
  pretty:     true
)
memory.delete rescue nil  # start each run clean

agent = SupportAgent.new(context: { language: "English" }, memory: memory)

log = []

questions = [
  { text: "What is the capital of the USA?",                    model: "meta-llama/llama-3.1-8b-instruct" },
  { text: "And what about Japan?",                              model: "mistralai/mistral-nemo" },
  { text: "Which of the two cities has a larger population?",   model: "openai/gpt-4.1-nano" }
]

fallback = { provider: :openrouter, model: "mistralai/mistral-nemo" }

questions.each_with_index do |q, i|
  agent.models.replace([
    { provider: :openrouter, model: q[:model] },
    fallback
  ])

  puts "\n[#{i + 1}] You: #{q[:text]}"
  result = agent.call(q[:text])
  puts "     AI : #{result.output}"
  puts "     via: #{result.model} (#{result.execution_time}s)"
  log << { model: result.model, time: result.execution_time }
end

section("Execution log")
log.each_with_index do |entry, i|
  puts "  [#{i + 1}] #{entry[:model].ljust(40)} #{entry[:time]}s"
end
puts "  " + "─" * 48
puts "  #{"total".ljust(40)} #{log.sum { |e| e[:time] }.round(3)}s"
