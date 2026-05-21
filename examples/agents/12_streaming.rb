# Run: ruby examples/agents/12_streaming.rb

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

header("12 — STREAMING (token by token)")

# ── 1. Instance API ──────────────────────────────────────────────────────────

section("1. agent.call with stream: lambda")

agent = SupportAgent.new(context: { language: "English" })

print "AI: "
result = agent.call("What are the three largest cities in the world?",
                    stream: ->(token) { print token; $stdout.flush })
puts "\n"
puts "Model : #{result.model}"
puts "Time  : #{result.execution_time}s"
puts "Full output length: #{result.output.length} chars"

# ── 2. Class API ─────────────────────────────────────────────────────────────

section("2. SupportAgent.call with stream: lambda")

print "AI: "
result2 = SupportAgent.call(
  input:   "Name three programming languages in one sentence.",
  context: { language: "English" },
  stream:  ->(token) { print token; $stdout.flush }
)
puts "\n"
puts "Model : #{result2.model}"
puts "Time  : #{result2.execution_time}s"
