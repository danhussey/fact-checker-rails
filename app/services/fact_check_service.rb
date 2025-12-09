class FactCheckService
  TIMEOUT = 45

  def self.verify(claim:, context:)
    new.verify(claim: claim, context: context)
  end

  def verify(claim:, context:)
    client = OpenAI::Client.new(
      access_token: Rails.application.credentials.xai_api_key,
      uri_base: "https://api.x.ai/v1",
      request_timeout: TIMEOUT
    )

    response = client.chat(
      parameters: {
        model: "grok-3-fast",
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt(claim, context) }
        ],
        temperature: 0.1
      }
    )

    result = JSON.parse(response.dig("choices", 0, "message", "content"))
    normalize_result(result)
  rescue Faraday::TimeoutError, Net::ReadTimeout
    Rails.logger.warn "[FactCheck] Timeout for claim: #{claim}"
    timeout_result
  rescue => e
    Rails.logger.error "[FactCheck] Error: #{e.message}"
    error_result(e.message)
  end

  private

  def system_prompt
    <<~PROMPT
      You are a fact checker. Evaluate the claim and return a JSON response with:

      {
        "verdict": "true" | "mostly_true" | "half_true" | "mostly_false" | "false" | "unverified",
        "confidence": 1-4,
        "whats_true": ["max 2 bullet points of what's accurate"],
        "whats_wrong": ["max 2 bullet points of what's inaccurate"],
        "context": ["max 2 bullet points of important context"],
        "sources": [{"name": "Source Name", "url": "optional URL"}]
      }

      Confidence scale:
      1 = unclear/contested topic
      2 = limited available data
      3 = good sources available
      4 = solid, well-documented data

      Guidelines:
      - Be brutally honest - no political balance for its own sake
      - Lead with numbers when available (e.g., "$44k vs $22k")
      - Use "unverified" for claims that cannot be fact-checked
      - Maximum 3 sources, prefer authoritative sources
      - Don't hallucinate URLs - use source names only if unsure of URL
    PROMPT
  end

  def user_prompt(claim, context)
    <<~PROMPT
      Claim to verify: #{claim}

      Recent conversation context:
      #{context.truncate(4000)}
    PROMPT
  end

  def normalize_result(result)
    {
      verdict: result["verdict"] || "unverified",
      confidence: result["confidence"]&.to_i&.clamp(1, 4) || 1,
      whats_true: Array(result["whats_true"]).first(2),
      whats_wrong: Array(result["whats_wrong"]).first(2),
      context_points: Array(result["context"]).first(2),
      sources: Array(result["sources"]).first(3).map do |s|
        { "name" => s["name"], "url" => s["url"] }
      end
    }
  end

  def timeout_result
    {
      verdict: "unverified",
      confidence: 1,
      whats_true: [],
      whats_wrong: [],
      context_points: ["Request timed out - try again"],
      sources: []
    }
  end

  def error_result(message)
    {
      verdict: "unverified",
      confidence: 1,
      whats_true: [],
      whats_wrong: [],
      context_points: ["Error during fact-check"],
      sources: []
    }
  end
end
