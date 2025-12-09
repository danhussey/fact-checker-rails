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

    Rails.logger.info "[ExtractClaims] Found #{claims.size} potential claims"

    claims.each do |claim|
      # Skip if too similar to existing claims
      if DuplicateDetector.similar?(claim, checked_claims)
        Rails.logger.debug "[ExtractClaims] Skipping duplicate: #{claim.truncate(50)}"
        next
      end

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
