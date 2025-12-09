module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :session_token

    def connect
      self.session_token = find_session_token
    end

    private

    def find_session_token
      # Accept session token from query params or cookies
      request.params[:session_token] ||
        cookies.encrypted[:session_token] ||
        reject_unauthorized_connection
    end
  end
end
