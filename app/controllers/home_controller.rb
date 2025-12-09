class HomeController < ApplicationController
  def index
    # Check if user has existing session
    if cookies.encrypted[:session_token]
      @session = ListeningSession.find_by(session_token: cookies.encrypted[:session_token])
    end
  end
end
