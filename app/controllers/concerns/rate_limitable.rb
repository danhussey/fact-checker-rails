module RateLimitable
  extend ActiveSupport::Concern

  class_methods do
    def rate_limit(to:, within:, by: nil)
      before_action do
        key_proc = by || -> { hashed_ip }
        key = "rate_limit:#{controller_name}:#{action_name}:#{instance_exec(&key_proc)}"

        count = Rails.cache.increment(key, 1, expires_in: within, raw: true).to_i

        if count > to
          retry_after = Rails.cache.read(key, raw: true) ? within.to_i : 60
          response.set_header("Retry-After", retry_after.to_s)
          render json: { error: "Rate limit exceeded. Try again later." }, status: :too_many_requests
        end
      end
    end
  end

  private

  def hashed_ip
    Digest::SHA256.hexdigest(request.remote_ip.to_s)[0, 12]
  end
end
