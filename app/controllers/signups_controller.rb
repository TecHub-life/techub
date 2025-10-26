class SignupsController < ApplicationController
  def new
  end

  def create
    invite_code = params.dig(:signup, :invite_code).to_s
    email = params.dig(:signup, :email).to_s

    # Invite code is required for new accounts
    if invite_code.strip.blank?
      flash.now[:alert] = "Invite code is required"
      return render :new, status: :unprocessable_entity
    end
    unless Access::InviteCodes.valid?(invite_code)
      flash.now[:alert] = "Invite code is invalid"
      return render :new, status: :unprocessable_entity
    end
    session[:invite_code] = invite_code
    session[:signup_email] = email.to_s.strip.downcase.presence

    redirect_to auth_github_path, allow_other_host: false
  end
end
