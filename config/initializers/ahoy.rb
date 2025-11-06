Ahoy.logger = Rails.logger
Ahoy.geocode = false
Ahoy.api = true

Ahoy.mask_ips = false
Ahoy.cookies = :none

class Ahoy::Store < Ahoy::DatabaseStore
  # share visit tokens across tabs via headers
  def visit_token
    request.headers["X-Visit-Token"].presence || super
  end
end
