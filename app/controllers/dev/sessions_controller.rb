module Dev
  class SessionsController < ApplicationController
    before_action :verify_dev_token!

    # GET /dev/sessions?token=xxx
    def index
      sessions = ListeningSession.recorded.order(created_at: :desc).limit(50)

      render json: sessions.map { |s|
        {
          id: s.id,
          created_at: s.created_at,
          chunks_count: s.transcript_chunks.count,
          fact_checks_count: s.fact_checks.count,
          download_url: download_dev_session_path(s, token: params[:token])
        }
      }
    end

    # GET /dev/sessions/:id?token=xxx
    def show
      session = ListeningSession.find(params[:id])

      render json: {
        id: session.id,
        created_at: session.created_at,
        status: session.status,
        recording_enabled: session.recording_enabled?,
        transcript_preview: session.transcript_chunks.final_only.limit(3).pluck(:text).join(" "),
        chunks_count: session.transcript_chunks.count,
        fact_checks_count: session.fact_checks.count
      }
    end

    # GET /dev/sessions/:id/download?token=xxx
    def download
      session = ListeningSession.find(params[:id])

      send_data session.export_data.to_json,
        filename: "session-#{session.id}-#{session.created_at.to_date}.json",
        type: "application/json"
    end

    private

    def verify_dev_token!
      expected_token = Rails.application.credentials.dev_export_token

      unless expected_token.present? && params[:token] == expected_token
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
