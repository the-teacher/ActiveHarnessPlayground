# Run: ruby examples/agents/09_streaming.rb

require_relative "../shared"

# ---------------------------------------------------------------------------
# 12 — Streaming output token by token
#
# Pass a `stream:` lambda to receive each token as it arrives from the API.
# The final Result is returned normally after the stream ends and contains
# the full accumulated output.
#
# Works the same way in Rails with SSE:
#
#   response.headers["Content-Type"] = "text/event-stream"
#   sse = SSE.new(response.stream)
#
#   SupportAgent.call(
#     input:  params[:input],
#     stream: ->(token) { sse.write({ token: token }) }
#   )
# ---------------------------------------------------------------------------

header("09 — STREAMING (token by token)")

# ── 1. Instance API ──────────────────────────────────────────────────────────

section("1. agent.call with stream: lambda")

agent = SupportAgent.new(context: { language: "English" })

question1 = "Explain in detail how the water cycle works, covering evaporation, " \
            "condensation, precipitation, and runoff. Give a thorough answer."

puts "You : #{question1}"
print "AI  : "
agent.call(question1, stream: ->(token) { print token; $stdout.flush })
result = agent.result
puts "\n"
puts "Model : #{result.model}"
puts "Time  : #{result.execution_time}s"
puts "Full output length: #{result.output.length} chars"

# ── 2. Class API ─────────────────────────────────────────────────────────────

section("2. SupportAgent.call with stream: lambda")

question2 = "Describe the main differences between object-oriented, functional, and " \
            "procedural programming paradigms with examples for each."

puts "You   : #{question2}"
print "AI    : "
result2 = SupportAgent.call(
  input:   question2,
  context: { language: "English" },
  stream:  ->(token) { print token; $stdout.flush }
)
puts "\n"
puts "Model : #{result2.model}"
puts "Time  : #{result2.execution_time}s"
