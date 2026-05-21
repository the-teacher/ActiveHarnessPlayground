require_relative "../agents/injection_guard_agent"
require_relative "../agents/translation_agent"
require_relative "../agents/compaction_agent"
require_relative "../tribunals/safety_tribunal"
require_relative "../agents/relevance_agent"
require_relative "../agents/support_agent"

class SupportPipeline < ActiveHarness::Pipeline
  # Step 1 — GUARD: detect prompt injection before wasting tokens
  step :injection_guard do
    use InjectionGuardAgent
    stop_if ->(result) { result.parsed["detected"] == true }
  end

  # Step 2 — TRANSFORM: translate to English for consistent downstream processing
  step :translate, TranslationAgent

  # Step 3 — TRANSFORM: compact to key intent, reduces tokens for expensive steps
  step :compact, CompactionAgent

  # Step 4 — TRIBUNAL: parallel toxicity + aggression check on compact English text
  step :safety_tribunal do
    use SafetyTribunal
    stop_if ->(result) { result.verdict == false }
  end

  # Step 5 — GUARD: topic relevance check on compact text
  step :relevance_guard do
    use RelevanceAgent
    stop_if ->(result) { result.parsed["relevant"] == false }
  end

  # Step 6 — TRANSFORM: final answer on a clean, safe, on-topic, compact request
  step :respond, SupportAgent

  # ── Global hooks (fire for every step) ──────────────────────────────────────

  before :step do |step_name, payload|
    snippet = payload.to_s.gsub(/\s+/, " ")[0..70]
    puts "[pipeline] → :#{step_name}  input: #{snippet.inspect}"
  end

  after :step do |step_name, result|
    time = result.respond_to?(:execution_time) ? "#{result.execution_time}s" : "?"
    puts "[pipeline] ✓ :#{step_name} (#{time})"
  end

  # ── Per-step hooks ───────────────────────────────────────────────────────────

  after :step, :injection_guard do |result|
    status = result.parsed["detected"] ? "INJECTION DETECTED" : "clean"
    puts "[injection_guard] → #{status}: #{result.parsed["reason"]}"
  end

  after :step, :translate do |result|
    puts "[translate] → #{result.output.to_s.gsub(/\s+/, " ")[0..80]}"
  end

  after :step, :compact do |result|
    puts "[compact]   → #{result.output.to_s.gsub(/\s+/, " ")[0..80]}"
  end

  after :step, :safety_tribunal do |result|
    puts "[safety_tribunal] verdict: #{result.verdict ? "SAFE" : "UNSAFE"}"
  end

  after :step, :relevance_guard do |result|
    status = result.parsed["relevant"] ? "relevant" : "OFF-TOPIC"
    puts "[relevance_guard] → #{status}: #{result.parsed["reason"]}"
  end

  # ── Terminal hooks ───────────────────────────────────────────────────────────

  callback :stopped do |step_name, result|
    puts "[pipeline] ✗ STOPPED at :#{step_name}"
  end

  callback :complete do |last_result|
    puts "[pipeline] ✓ pipeline complete"
  end
end
