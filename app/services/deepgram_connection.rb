require "websocket-client-simple"

class DeepgramConnection
  DEEPGRAM_URL = "wss://api.deepgram.com/v1/listen"

  QUERY_PARAMS = {
    model: "nova-2",
    language: "en",
    punctuate: "true",
    smart_format: "true",
    interim_results: "true",
    utterances: "true",
    vad_events: "true",
    encoding: "linear16",
    sample_rate: "16000"
  }.freeze

  attr_reader :connected

  def initialize(on_partial:, on_final:, on_utterance_end:, on_error:)
    @on_partial = on_partial
    @on_final = on_final
    @on_utterance_end = on_utterance_end
    @on_error = on_error
    @socket = nil
    @connected = false
  end

  def connect!
    url = "#{DEEPGRAM_URL}?#{URI.encode_www_form(QUERY_PARAMS)}"

    @socket = WebSocket::Client::Simple.connect(url, headers: {
      "Authorization" => "Token #{Rails.application.credentials.deepgram_api_key}"
    })

    setup_handlers
    @connected = true

    Rails.logger.info "[Deepgram] Connection initiated"
  rescue => e
    Rails.logger.error "[Deepgram] Connection failed: #{e.message}"
    @on_error.call(e.message)
  end

  def send_audio(binary_data)
    return unless @socket && @connected

    @socket.send(binary_data, type: :binary)
  rescue => e
    Rails.logger.error "[Deepgram] Send failed: #{e.message}"
    @on_error.call(e.message)
  end

  def close
    @connected = false
    @socket&.close
    Rails.logger.info "[Deepgram] Connection closed"
  rescue => e
    Rails.logger.error "[Deepgram] Close failed: #{e.message}"
  end

  def connected?
    @connected && @socket&.open?
  end

  private

  def setup_handlers
    connection = self

    @socket.on :message do |msg|
      connection.send(:handle_message, msg.data)
    end

    @socket.on :open do
      Rails.logger.info "[Deepgram] WebSocket opened"
    end

    @socket.on :error do |e|
      Rails.logger.error "[Deepgram] WebSocket error: #{e.message}"
      connection.instance_variable_get(:@on_error).call(e.message)
    end

    @socket.on :close do |e|
      Rails.logger.info "[Deepgram] WebSocket closed: #{e&.code}"
      connection.instance_variable_set(:@connected, false)
    end
  end

  def handle_message(data)
    parsed = JSON.parse(data)

    case parsed["type"]
    when "Results"
      handle_results(parsed)
    when "UtteranceEnd"
      @on_utterance_end.call
    when "Metadata"
      Rails.logger.debug "[Deepgram] Metadata: #{parsed}"
    when "Error"
      Rails.logger.error "[Deepgram] Error from API: #{parsed}"
      @on_error.call(parsed["message"] || "Unknown Deepgram error")
    end
  rescue JSON::ParserError => e
    Rails.logger.error "[Deepgram] JSON parse error: #{e.message}"
  end

  def handle_results(data)
    channel = data.dig("channel", "alternatives", 0)
    return unless channel

    transcript = channel["transcript"]
    return if transcript.blank?

    result = {
      transcript: transcript,
      confidence: channel["confidence"],
      words: channel["words"],
      start: data["start"],
      duration: data["duration"],
      is_final: data["is_final"],
      speech_final: data["speech_final"]
    }

    if data["is_final"]
      @on_final.call(result)
    else
      @on_partial.call(result[:transcript])
    end
  end
end
