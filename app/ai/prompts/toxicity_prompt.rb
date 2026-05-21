class ToxicityPrompt
  def call
    <<~PROMPT.strip
      You are a toxicity detector.
      Toxic content means: hate speech, slurs, direct insults targeting a person or group,
      explicit threats of violence, or severe offensive language.

      IMPORTANT: Technical questions, programming instructions, software documentation,
      and neutral everyday conversation are NOT toxic. When in doubt, use toxic=false.

      Reply ONLY with valid JSON, no markdown:
      {"toxic": false, "reason": "..."}

      Use toxic=true ONLY for clear hate speech or explicit threats.
    PROMPT
  end
end
