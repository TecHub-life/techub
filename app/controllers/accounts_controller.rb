class AccountsController < ApplicationController
  before_action :require_login

  def edit
    @user = current_user || User.find_by(id: session[:current_user_id])
  end

  def update
    @user = current_user || User.find_by(id: session[:current_user_id])
    attrs = account_params.to_h
    if attrs.key?("notify_on_pipeline")
      attrs["notify_on_pipeline"] = ActiveModel::Type::Boolean.new.cast(attrs["notify_on_pipeline"])
    end
    if attrs.key?("email")
      attrs["email"] = attrs["email"].to_s.strip.downcase
    end
    if @user.update(attrs)
      redirect_to edit_account_path, notice: "Account updated"
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_login
    @current_user ||= User.find_by(id: session[:current_user_id]) if @current_user.nil? && session[:current_user_id].present?
    redirect_to login_path, alert: "Please sign in" unless current_user
  end

  def account_params
    params.require(:user).permit(:email, :notify_on_pipeline)
  end
end
