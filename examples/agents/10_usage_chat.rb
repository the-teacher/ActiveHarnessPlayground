# Run: ruby examples/agents/10_usage_chat.rb

require_relative "../shared"

# ---------------------------------------------------------------------------
# 13 — Chat with token usage tracking
#
# Each call accumulates token usage — useful for estimating API costs.
# result.usage returns: { input_tokens:, output_tokens:, total_tokens: }
#
# Approximate cost formula (OpenRouter pricing example):
#   cost = (input_tokens  / 1_000_000.0 * input_price_per_m) +
#          (output_tokens / 1_000_000.0 * output_price_per_m)
# ---------------------------------------------------------------------------

header("10 — CHAT WITH USAGE TRACKING")

# mistralai/mistral-nemo pricing on OpenRouter (as of 2025):
#   input:  $0.035 / 1M tokens
#   output: $0.08  / 1M tokens
INPUT_PRICE_PER_M  = 0.035
OUTPUT_PRICE_PER_M = 0.080

def cost_usd(usage)
  return nil unless usage
  (usage[:input_tokens]  / 1_000_000.0 * INPUT_PRICE_PER_M) +
  (usage[:output_tokens] / 1_000_000.0 * OUTPUT_PRICE_PER_M)
end

agent = SupportAgent.new(context: { language: "English" })

log = []

questions = [
  "What is your return policy?",
  "Does that also apply to digital products?",
  "How long does a refund usually take?"
]

questions.each_with_index do |question, i|
  puts "\n[#{i + 1}] You: #{question}"
  agent.call(question)
  result = agent.result
  puts "     AI : #{result.output}"

  u = result.usage
  if u
    call_cost = cost_usd(u)
    puts "     in=#{u[:input_tokens]} out=#{u[:output_tokens]} total=#{u[:total_tokens]} tokens | ~$#{"%.6f" % call_cost}"
    log << { model: result.model, time: result.execution_time, usage: u, cost: call_cost }
  else
    puts "     usage: n/a"
    log << { model: result.model, time: result.execution_time, usage: nil, cost: nil }
  end
end

section("Usage summary")

total_input  = log.sum { |e| e.dig(:usage, :input_tokens).to_i }
total_output = log.sum { |e| e.dig(:usage, :output_tokens).to_i }
total_tokens = log.sum { |e| e.dig(:usage, :total_tokens).to_i }
total_cost   = log.sum { |e| e[:cost].to_f }
total_time   = log.sum { |e| e[:time] }

puts "  #{"call".ljust(4)}  #{"model".ljust(32)}  #{"in".rjust(6)}  #{"out".rjust(6)}  #{"total".rjust(7)}  #{"cost".rjust(10)}  time"
puts "  " + "─" * 82
log.each_with_index do |e, i|
  u = e[:usage]
  cost_str = e[:cost] ? "~$#{"%.6f" % e[:cost]}" : "n/a"
  if u
    puts "  [#{i + 1}]   #{e[:model].ljust(32)}  #{u[:input_tokens].to_s.rjust(6)}  #{u[:output_tokens].to_s.rjust(6)}  #{u[:total_tokens].to_s.rjust(7)}  #{cost_str.rjust(10)}  #{e[:time]}s"
  else
    puts "  [#{i + 1}]   #{e[:model].ljust(32)}  #{"n/a".rjust(6)}  #{"n/a".rjust(6)}  #{"n/a".rjust(7)}  #{"n/a".rjust(10)}  #{e[:time]}s"
  end
end
puts "  " + "─" * 82
puts "  #{"TOTAL".ljust(38)}  #{total_input.to_s.rjust(6)}  #{total_output.to_s.rjust(6)}  #{total_tokens.to_s.rjust(7)}  #{"~$#{"%.6f" % total_cost}".rjust(10)}  #{total_time.round(3)}s"
