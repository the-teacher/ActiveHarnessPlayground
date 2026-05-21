# Run: ruby examples/agents/02_multiple_agents_sequential.rb

require_relative "../shared"

# ---------------------------------------------------------------------------
# 02 — Multiple agents, sequential execution
#
# Each agent answers the same question in a different language.
# Agents run one after another; total time is the sum of individual times.
# ---------------------------------------------------------------------------

header("02 — MULTIPLE AGENTS (sequential)")

agents = {
  "Russian" => SupportAgent.new(input: "What is USA capital?", context: { language: "Russian" }),
  "French"  => SupportAgent.new(input: "What is USA capital?", context: { language: "French" }),
  "German"  => SupportAgent.new(input: "What is USA capital?", context: { language: "German" })
}

total_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

agents.each do |lang, agent|
  puts "\n--- #{lang} ---"
  t0     = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  result = agent.call
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0

  puts "Output   : #{result.output}"
  puts "Model    : #{result.model}"
  puts "Time     : #{"%.2f" % elapsed}s"
end

total = Process.clock_gettime(Process::CLOCK_MONOTONIC) - total_start
puts "\nTotal time (sequential): #{"%.2f" % total}s"
