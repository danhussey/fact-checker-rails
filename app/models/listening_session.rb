class ListeningSession < ApplicationRecord
  has_many :transcript_chunks, dependent: :destroy
  has_many :fact_checks, dependent: :destroy

  enum :status, { idle: "idle", listening: "listening", processing: "processing" }

  scope :recorded, -> { where(recording_enabled: true) }

  before_create :generate_session_token

  def enable_recording!
    update!(recording_enabled: true)
  end

  def recent_transcript(minutes: 5)
    transcript_chunks
      .where(is_final: true)
      .where("created_at > ?", minutes.minutes.ago)
      .order(:created_at)
      .pluck(:text)
      .join(" ")
  end

  def checked_claims
    fact_checks.pluck(:claim)
  end

  # Export all raw data for pipeline evaluation
  def export_data
    {
      session: {
        id: id,
        created_at: created_at,
        duration_seconds: transcript_chunks.maximum(:end_time)
      },
      transcript_chunks: transcript_chunks.where(is_final: true).order(:start_time).map do |chunk|
        {
          text: chunk.text,
          start_time: chunk.start_time,
          end_time: chunk.end_time,
          confidence: chunk.confidence,
          words: chunk.words
        }
      end,
      fact_checks: fact_checks.order(:created_at).map do |fc|
        {
          claim: fc.claim,
          verdict: fc.verdict,
          confidence: fc.confidence,
          whats_true: fc.whats_true,
          whats_wrong: fc.whats_wrong,
          context_points: fc.context_points,
          sources: fc.sources,
          status: fc.status,
          triggered_at: fc.created_at,
          completed_at: fc.completed_at
        }
      end
    }
  end

  private

  def generate_session_token
    self.session_token ||= SecureRandom.uuid
  end
end
