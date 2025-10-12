class AccountsController < ApplicationController
  before_action :require_login

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(account_params)
      redirect_to edit_account_path, notice: "Account updated"
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_login
    redirect_to auth_github_path, alert: "Please sign in with GitHub" unless current_user
  end

  def account_params
    params.require(:user).permit(:email, :notify_on_pipeline)
  end
end
