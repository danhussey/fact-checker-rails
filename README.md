# Fact Check - Rails 8

Real-time AI-powered fact-checking with streaming transcription.

## Architecture

- **Rails 8** with Hotwire (Turbo + Stimulus)
- **Deepgram** for streaming speech-to-text (WebSocket)
- **xAI Grok** for claim extraction and fact-checking
- **Solid Queue** for background jobs
- **Solid Cache** for rate limiting
- **Solid Cable** for Action Cable (WebSocket)
- **SQLite** (dev) / **PostgreSQL** (prod)

## Setup

```bash
# Install dependencies
bundle install

# Set up credentials (see below)
rails credentials:edit

# Create database
rails db:create db:migrate

# Start the server
bin/dev
```

## Required Credentials

Edit credentials with `rails credentials:edit`:

```yaml
deepgram_api_key: your_deepgram_api_key
xai_api_key: your_xai_api_key
dev_export_token: your_secret_token_for_dev_export
```

Get API keys:
- Deepgram: https://console.deepgram.com/
- xAI: https://console.x.ai/

## How It Works

1. User clicks "Start Listening"
2. Browser captures microphone audio via Web Audio API
3. Audio streamed to Rails via Action Cable
4. Rails relays audio to Deepgram WebSocket
5. Deepgram returns real-time transcripts
6. On utterance end, `ExtractClaimsJob` finds factual claims
7. `FactCheckJob` verifies each claim via Grok
8. Results broadcast to browser via Turbo Streams

## Dev Session Export

Enable recording on a session (click REC button), then:

```bash
# List recorded sessions
curl "http://localhost:3000/dev/sessions?token=your_dev_export_token"

# Download session data
curl "http://localhost:3000/dev/sessions/1/download?token=your_dev_export_token" > session.json
```

## Project Structure

```
app/
├── channels/
│   └── transcription_channel.rb    # Action Cable for audio streaming
├── controllers/
│   ├── listening_sessions_controller.rb
│   ├── dev/sessions_controller.rb  # Dev export
│   └── concerns/rate_limitable.rb
├── jobs/
│   ├── extract_claims_job.rb       # Claim extraction
│   └── fact_check_job.rb           # Fact verification
├── models/
│   ├── listening_session.rb
│   ├── transcript_chunk.rb
│   └── fact_check.rb
├── services/
│   ├── deepgram_connection.rb      # WebSocket client
│   ├── claim_extraction_service.rb # Grok integration
│   ├── fact_check_service.rb       # Grok integration
│   └── duplicate_detector.rb       # Dedup claims
├── javascript/
│   └── controllers/
│       └── streaming_transcription_controller.js
└── views/
    ├── listening_sessions/show.html.erb
    └── fact_checks/_fact_check.html.erb
```

## Running Jobs

Jobs run via Solid Queue. In development, `bin/dev` starts both web and jobs.

For production:
```bash
bin/jobs  # Run job workers
```
