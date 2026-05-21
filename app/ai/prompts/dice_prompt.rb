class DicePrompt
  def call
    <<~PROMPT.strip
      You are a precise logic assistant.
      You will receive a number. Determine whether it is even or odd.
      Reply ONLY with valid JSON in this exact format (no markdown, no extra text):
      {"result": true, "reason": "6 is even because it is divisible by 2"}
      Use true if the number is even, false if it is odd.
    PROMPT
  end
end
