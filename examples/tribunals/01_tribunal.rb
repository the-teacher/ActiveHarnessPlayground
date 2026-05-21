# Run: ruby examples/tribunals/01_tribunal.rb

require_relative "../shared"
require_relative "../../app/ai/tribunals/content_quality_tribunal"

header("Example 01 — Tribunal (parallel multi-agent verdict)")

input = "I hate this product, it's completely useless!"
puts "\nInput: #{input.inspect}\n\n"

tribunal = ContentQualityTribunal.new(input: input)

puts "--- Running ---\n\n"
tribunal.call

puts "\n--- Individual results ---"
tribunal.results.each do |result|
  puts "  model:          #{result.model}"
  puts "  input:          #{result.input}"
  puts "  system_prompt:  #{result.system_prompt}"
  puts "  result:         #{result.parsed["result"].inspect}"
  puts "  reason:         #{result.parsed["reason"]}"
  puts "  execution_time: #{result.execution_time}s"
  if result.attempts.any?
    puts "  failed attempts:"
    result.attempts.each do |a|
      puts "    #{a[:model]}: #{a[:error]} (#{a[:execution_time]}s)"
    end
  end
  puts
end

unless tribunal.errors.empty?
  puts "--- Errors ---"
  tribunal.errors.each do |e|
    puts "  #{e[:agent]}: #{e[:error].message}"
  end
  puts
end

puts "--- Execution times ---"
tribunal.agent_execution_times.each do |entry|
  puts "  #{entry[:agent]}: #{entry[:time]}s"
end
puts "  total: #{tribunal.execution_time}s"

puts "\n--- Verdict ---"
puts "  => #{tribunal.verdict ? "APPROVED (all agents agreed)" : "REJECTED (one or more agents declined)"}"
