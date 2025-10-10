class Current < ActiveSupport::CurrentAttributes
  attribute :request_id, :user_id, :ip, :user_agent, :path, :method, :session_id

  resets { Time.zone = nil }
end
