# Run: ruby examples/agents/03_parallel_agents.rb

require_relative "../shared"

# ---------------------------------------------------------------------------
# 03 — Parallel agents with Concurrent::Future  (like Promise.all)
#
# All three agents fire their HTTP requests simultaneously.
# Total time ≈ the slowest single request, not the sum of all three.
#
# .value! blocks until the future finishes and re-raises any exception
# that occurred inside the thread — safe equivalent of Promise.all.
# ---------------------------------------------------------------------------

header("03 — PARALLEL AGENTS (Concurrent::Future)")

agents = {
  "Russian" => SupportAgent.new(input: "What is USA capital?", context: { language: "Russian" }),
  "French"  => SupportAgent.new(input: "What is USA capital?", context: { language: "French" }),
  "German"  => SupportAgent.new(input: "What is USA capital?", context: { language: "German" })
}

start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

futures = agents.map do |lang, agent|
  Concurrent::Future.execute { [lang, agent.call.result] }
end

results = futures.map(&:value!)

elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

results.each do |lang, result|
  puts "\n--- #{lang} ---"
  puts "Output : #{result.output}"
  puts "Model  : #{result.model}"
end

puts "\nTotal time (parallel, #{agents.size} agents): #{"%.2f" % elapsed}s"
