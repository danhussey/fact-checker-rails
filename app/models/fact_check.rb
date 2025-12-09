class FactCheck < ApplicationRecord
  belongs_to :listening_session
  belongs_to :triggered_by_chunk, class_name: "TranscriptChunk", optional: true

  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }

  enum :verdict, {
    verdict_true: "true",
    mostly_true: "mostly_true",
    half_true: "half_true",
    mostly_false: "mostly_false",
    verdict_false: "false",
    unverified: "unverified"
  }, prefix: true

  scope :completed, -> { where(status: "completed") }

  # Broadcast updates to the session
  after_create_commit :broadcast_creation
  after_update_commit -> { broadcast_replace_to listening_session }

  def broadcast_creation
    # Remove empty state if this is the first fact check
    broadcast_remove_to listening_session, target: "empty_state"
    # Prepend new fact check at top
    broadcast_prepend_to listening_session, target: "fact_checks"
  end

  def verdict_label
    case verdict
    when "true" then "TRUE"
    when "mostly_true" then "MOSTLY TRUE"
    when "half_true" then "HALF TRUE"
    when "mostly_false" then "MOSTLY FALSE"
    when "false" then "FALSE"
    when "unverified" then "UNVERIFIED"
    else "CHECKING"
    end
  end

  def verdict_color
    case verdict
    when "true" then "green"
    when "mostly_true" then "lime"
    when "half_true" then "yellow"
    when "mostly_false" then "orange"
    when "false" then "red"
    when "unverified" then "zinc"
    else "zinc"
    end
  end

  def confidence_label
    case confidence
    when 1 then "weak"
    when 2 then "limited"
    when 3 then "good"
    when 4 then "solid"
    else nil
    end
  end
end
