class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :load_current_user
  before_action :set_current_request_context

  helper_method :current_user

  private

  def load_current_user
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
