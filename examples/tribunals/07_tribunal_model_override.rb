# Run: ruby examples/tribunals/07_tribunal_model_override.rb

require_relative "../shared"
require_relative "../../app/ai/tribunals/politeness_tribunal"

header("Example 07 — Tribunal: same agent, different models")

input = "I hate this product, it's completely useless!"
puts "\nInput: #{input.inspect}\n\n"

tribunal = PolitenessTribunal.new(input: input)
tribunal.call

puts "--- Individual results ---"
tribunal.results.each do |result|
  puts "  model:  #{result.model}"
  puts "  result: #{result.parsed["result"].inspect}"
  puts "  reason: #{result.parsed["reason"]}"
  puts
end

unless tribunal.errors.empty?
  puts "--- Errors ---"
  tribunal.errors.each do |e|
    puts "  #{e[:agent]}: #{e[:error].message}"
  end
  puts
end

puts "--- Verdict ---"
puts "  => #{tribunal.verdict ? \
  "APPROVED (all models agreed)" : \
  "REJECTED (one or more models declined)"}"
