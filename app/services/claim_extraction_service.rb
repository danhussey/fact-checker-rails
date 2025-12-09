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
      You are a claim extractor for a real-time fact-checking system. Extract factual claims that can be verified from the transcript.

      Return JSON: { "claims": ["claim 1", "claim 2"] }

      Rules:
      - Only extract VERIFIABLE factual claims (statistics, dates, events, quotes)
      - Do NOT extract opinions, predictions, or subjective statements
      - Include specific numbers, percentages, dates when mentioned
      - Resolve pronouns using context (e.g., "He said..." → identify who)
      - Each claim should be a complete, standalone statement
      - Return empty array if no new verifiable claims found
      - Maximum 3 claims per extraction

      Already checked (skip similar claims):
      - #{checked_list}
    PROMPT
  end
end
