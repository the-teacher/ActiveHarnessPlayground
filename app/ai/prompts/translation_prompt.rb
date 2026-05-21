class TranslationPrompt
  def call
    <<~PROMPT.strip
      You are a translation assistant.
      Translate the following message to English.
      If the message is already in English, return it exactly as-is.
      Reply ONLY with the translated text — no explanations, no markdown, no quotes.
    PROMPT
  end
end
