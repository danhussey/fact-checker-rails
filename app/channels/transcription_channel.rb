class TranscriptionChannel < ApplicationCable::Channel
  def subscribed
    @session = ListeningSession.find_by!(session_token: params[:session_token])
    stream_for @session

    # Open persistent WebSocket to Deepgram
    @deepgram = DeepgramConnection.new(
      on_partial: ->(text) { broadcast_partial(text) },
      on_final: ->(result) { handle_final_transcript(result) },
      on_utterance_end: -> { handle_utterance_end },
      on_error: ->(error) { broadcast_error(error) }
    )
    @deepgram.connect!

    @session.update!(status: :listening)
    Rails.logger.info "[Transcription] Session #{@session.id} started listening"
  rescue ActiveRecord::RecordNotFound
    reject
  end

  # Receive binary audio data from browser (base64 encoded)
  def receive(data)
    return unless @deepgram&.connected?

    # Decode base64 audio and forward to Deepgram
    audio_bytes = Base64.decode64(data["audio"])
    @deepgram.send_audio(audio_bytes)
  end

  def unsubscribed
    @deepgram&.close
    @session&.update!(status: :idle)

    Rails.logger.info "[Transcription] Session #{@session&.id} stopped listening"
  end

  private

  def broadcast_partial(text)
    TranscriptionChannel.broadcast_to(@session, {
      type: "partial",
      text: text
    })
  end

  def handle_final_transcript(result)
    # Save to database
    chunk = @session.transcript_chunks.create!(
      text: result[:transcript],
      is_final: true,
      confidence: result[:confidence],
      start_time: result[:start],
      end_time: result[:start] + result[:duration],
      words: result[:words]
    )

    # Broadcast final to browser
    TranscriptionChannel.broadcast_to(@session, {
      type: "final",
      text: result[:transcript],
      chunk_id: chunk.id
    })
  end

  def handle_utterance_end
    # Trigger claim extraction when speaker pauses
    ExtractClaimsJob.perform_later(session_id: @session.id)
  end

  def broadcast_error(error)
    TranscriptionChannel.broadcast_to(@session, {
      type: "error",
      message: error
    })
  end
end
