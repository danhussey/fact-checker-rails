class ListeningSessionsController < ApplicationController
  before_action :set_session, only: [:show, :toggle_recording]

  def create
    @session = ListeningSession.create!
    cookies.encrypted[:session_token] = {
      value: @session.session_token,
      httponly: true,
      same_site: :lax
    }
    redirect_to @session
  end

  def show
    @fact_checks = @session.fact_checks.order(created_at: :desc)
  end

  def toggle_recording
    if @session.recording_enabled?
      @session.update!(recording_enabled: false)
    else
      @session.enable_recording!
    end

    head :ok
  end

  private

  def set_session
    @session = ListeningSession.find(params[:id])
  end
end
