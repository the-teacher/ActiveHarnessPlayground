class SupportPrompt
  def call
    # @input, @context and @config are injected automatically by the agent
    # before this method is called — use them freely to build dynamic prompts.
    base = "You are a concise and friendly customer support assistant. " \
           "Answer briefly, in 2-3 sentences max."

    return base unless @context[:language]

    "#{base} Always respond in #{@context[:language]}."
  end
end
