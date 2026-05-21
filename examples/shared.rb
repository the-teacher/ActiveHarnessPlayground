require "bundler/setup"
require "active_harness"
require "concurrent"

# ---------------------------------------------------------------------------
# Load .env from playground/.env
# ---------------------------------------------------------------------------
env_file = File.join(File.expand_path("../..", __FILE__), ".env")

if File.exist?(env_file)
  File.foreach(env_file) do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")

    key, value = line.split("=", 2)
    ENV[key.strip] = value.strip if key && value
  end
  puts "Loaded #{env_file}"
else
  puts "WARNING: #{env_file} not found."
end

# ---------------------------------------------------------------------------
# Load app
# ---------------------------------------------------------------------------
require_relative "../app/ai/agents/support_agent"

# ---------------------------------------------------------------------------
# Display helpers — available in all examples
# ---------------------------------------------------------------------------
def header(title)
  puts "\n#{'=' * 60}"
  puts title
  puts "=" * 60
end

def section(title)
  puts "\n" + "─" * 60
  puts title
  puts "─" * 60
end

