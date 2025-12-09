module ApplicationCable
  class Channel < ActionCable::Channel::Base
    # Override to prevent logging raw audio data
    def dispatch_action(action, data)
      if data&.key?("audio")
        receive(data) # Skip logging entirely for audio frames
      else
        super
      end
    end
  end
end
