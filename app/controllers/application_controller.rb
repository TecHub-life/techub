class ApplicationController < ActionController::Base
  include Ahoy::Controller
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :load_current_user
  before_action :set_current_request_context

  helper_method :current_user

  private

  def load_current_user
    # Allow explicit test header to set current user without touching Rack session
    if Rails.env.test?
      test_uid = request.headers["X-Test-User-Id"].presence
      if test_uid
        @current_user ||= User.find_by(id: test_uid)
        return
      end
    end

    return if session[:current_user_id].blank?

    @current_user ||= User.find_by(id: session[:current_user_id])
    session.delete(:current_user_id) if @current_user.nil?
  end

  def current_user
    @current_user
  end

  def set_current_request_context
    Current.request_id = request.request_id
    Current.user_id = current_user&.id
    Current.ip = request.remote_ip
    Current.user_agent = request.user_agent
    Current.path = request.path
    Current.method = request.request_method
    Current.session_id = session.id.private_id rescue nil
  end
end
