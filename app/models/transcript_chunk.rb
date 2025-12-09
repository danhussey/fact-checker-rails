class TranscriptChunk < ApplicationRecord
  belongs_to :listening_session

  scope :final_only, -> { where(is_final: true) }
  scope :recent, ->(minutes = 5) { where("created_at > ?", minutes.minutes.ago) }

  after_create_commit :broadcast_to_session

  private

  def broadcast_to_session
    return unless is_final?

    broadcast_append_to(
      listening_session,
      target: "transcript",
      partial: "transcript_chunks/chunk",
      locals: { chunk: self }
    )
  end
end
