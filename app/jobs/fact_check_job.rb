class FactCheckJob < ApplicationJob
  queue_as :fact_checking

  def perform(fact_check_id:)
    fact_check = FactCheck.find(fact_check_id)

    # Mark as processing
    fact_check.update!(
      status: :processing,
      processing_started_at: Time.current
    )

    # Get context for fact-checking
    context = fact_check.listening_session.recent_transcript(minutes: 5)

    # Perform fact-check
    result = FactCheckService.verify(
      claim: fact_check.claim,
      context: context
    )

    # Update with results
    fact_check.update!(
      status: :completed,
      completed_at: Time.current,
      verdict: result[:verdict],
      confidence: result[:confidence],
      whats_true: result[:whats_true],
      whats_wrong: result[:whats_wrong],
      context_points: result[:context_points],
      sources: result[:sources]
    )

    Rails.logger.info "[FactCheck] Completed: #{fact_check.claim.truncate(50)} → #{result[:verdict]}"
  rescue => e
    Rails.logger.error "[FactCheck] Failed: #{e.message}"
    fact_check.update!(
      status: :failed,
      error_message: e.message
    )
  end
end
