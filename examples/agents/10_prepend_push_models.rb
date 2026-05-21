# Run: ruby examples/agents/10_prepend_push_models.rb

require_relative "../shared"

# ---------------------------------------------------------------------------
# 10 — Prepend and push models at runtime via agent.models
#
# The class defines its model chain via `model do...end`.
# After instantiation you can call:
#
#   agent.models.prepend([...])  — insert models BEFORE the class chain
#   agent.models.push([...])     — append models AFTER the class chain
#
# Final order: [prepended] + [class chain] + [pushed]
#
# Useful when you want to:
#   - Try an experimental model first, before the stable chain
#   - Attach a guaranteed-free fallback at the very end
#   - Compose model chains dynamically without touching the class definition
# ---------------------------------------------------------------------------

header("10 — PREPEND / PUSH models at runtime")

def print_chain(label, agent)
  puts "\n#{label}"
  agent.models.to_a.each_with_index do |m, i|
    temp = m[:temperature] ? " (temp: #{m[:temperature]})" : ""
    puts "  [#{i}] #{m[:provider]}/#{m[:model]}#{temp}"
  end
end

# 1. Default chain — no modifications
default_agent = SupportAgent.new(input: "What is the capital of Japan?",
                                 context: { language: "English" })
print_chain("1. Default class chain", default_agent)

# 2. Prepend one model — it becomes position [0]
prepend_agent = SupportAgent.new(input: "What is the capital of Japan?",
                                 context: { language: "English" })
prepend_agent.models.prepend([
  { provider: :openrouter, model: "mistralai/mistral-nemo", temperature: 0.9 }
])
print_chain("2. After prepend (1 model added at front)", prepend_agent)

# 3. Push one model — it becomes the last fallback
push_agent = SupportAgent.new(input: "What is the capital of Japan?",
                              context: { language: "English" })
push_agent.models.push([
  { provider: :openrouter, model: "mistralai/mistral-nemo", temperature: 0.1 }
])
print_chain("3. After push (1 model added at end)", push_agent)

# 4. Both prepend and push — sandwich the class chain
both_agent = SupportAgent.new(input: "What is the capital of Japan?",
                              context: { language: "Spanish" })
both_agent.models
  .prepend([{ provider: :openrouter, model: "openai/gpt-4.1-nano", temperature: 0.3 }])
  .push([{ provider: :openrouter, model: "meta-llama/llama-3.2-3b-instruct:free" }])
print_chain("4. After prepend + push (sandwiched chain)", both_agent)

# 5. Insert at arbitrary position
insert_agent = SupportAgent.new(input: "What is the capital of Japan?",
                               context: { language: "English" })
insert_agent.models.insert(1, { provider: :openrouter, model: "openai/gpt-4.1-nano", temperature: 0.7 })
print_chain("5. After insert at position 1", insert_agent)

# 6. Actually call — uses the runtime-modified chain
puts "\n--- Calling with the pushed-chain agent ---"
result = push_agent.call
puts "Model  : #{result.model}"
puts "Output : #{result.output}"
puts "Chain  :"
puts result.model_list.map { |m| "  => #{m[:provider]}/#{m[:model]}" }.join("\n")
