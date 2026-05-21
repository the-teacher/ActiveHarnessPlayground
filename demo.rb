# ---------------------------------------------------------------------------
# demo.rb — runs all numbered examples from examples/
# ---------------------------------------------------------------------------
# Run individual example:   bundle exec ruby examples/01_basic_call.rb
# Run all at once:          bundle exec ruby demo.rb
# ---------------------------------------------------------------------------

Dir[File.join(__dir__, "examples", "**", "[0-9]*.rb")].sort_by { |f| File.basename(f) }.each do |example|
  puts "\n\n#{"#" * 60}"
  puts "# #{File.basename(example)}"
  puts "#" * 60
  load example
end
