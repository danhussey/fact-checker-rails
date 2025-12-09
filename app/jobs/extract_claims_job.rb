class ExtractClaimsJob < ApplicationJob
  queue_as :claims

  def perform(session_id:)
    session = ListeningSession.find(session_id)

    # Get recent context (last 5 minutes of final transcripts)
    context = session.recent_transcript(minutes: 5)
    return if context.length < 50

    # Get already-checked claims for dedup
    checked_claims = session.checked_claims

    # Extract claims via Grok
    claims = ClaimExtractionService.extract(
      context: context,
      checked_claims: checked_claims
    )

    return if claims.empty?
    Rails.logger.info "[Claims] Extracted #{claims.size}: #{claims.map { |c| c.truncate(40) }.join(' | ')}"

    claims.each do |claim|
      next if DuplicateDetector.similar?(claim, checked_claims)

      # Create fact check record
      fact_check = session.fact_checks.create!(
        claim: claim,
        status: :pending
      )

      # Enqueue fact-checking
      FactCheckJob.perform_later(fact_check_id: fact_check.id)

      # Add to checked list for subsequent dedup
      checked_claims << claim
    end
  end
end
