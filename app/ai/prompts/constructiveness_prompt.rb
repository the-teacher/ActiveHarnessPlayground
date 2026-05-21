class ConstructivenessPrompt
  def call
    <<~PROMPT.strip
      You are a constructiveness evaluator.
      Analyze the following message and decide whether it is constructive.
      Reply ONLY with valid JSON, no markdown:
      {"result": true, "reason": "..."}
      Use true if constructive, false if not.
    PROMPT
  end
end
