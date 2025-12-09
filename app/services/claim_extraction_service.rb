class ClaimExtractionService
  def self.extract(context:, checked_claims:)
    new.extract(context: context, checked_claims: checked_claims)
  end

  def extract(context:, checked_claims:)
    return [] if context.length < 50

    client = OpenAI::Client.new(
      access_token: Rails.application.credentials.xai_api_key,
      uri_base: "https://api.x.ai/v1"
    )

    response = client.chat(
      parameters: {
        model: "grok-3-fast",
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: system_prompt(checked_claims) },
          { role: "user", content: context }
        ],
        temperature: 0.1
      }
    )

    parsed = JSON.parse(response.dig("choices", 0, "message", "content"))
    parsed["claims"] || []
  rescue => e
    Rails.logger.error "[ClaimExtraction] Error: #{e.message}"
    []
  end

  private

  def system_prompt(checked_claims)
    checked_list = checked_claims.any? ? checked_claims.join("\n- ") : "(none yet)"

    <<~PROMPT
      Extract factual claims from this live transcript for fact-checking.

      Return JSON: { "claims": ["claim 1", "claim 2"] }

      Guidelines:
      - Extract statements that can be verified as true or false
      - Include claims about: statistics, geography, history, science, comparisons, quotes
      - Combine fragmented sentences into complete claims (e.g., "Russia." + "Is in America." → "Russia is in America")
      - Rephrase for clarity while preserving meaning
      - Skip opinions and predictions
      - Maximum 3 new claims

      Already checked (skip these):
      - #{checked_list}
    PROMPT
  end
end
