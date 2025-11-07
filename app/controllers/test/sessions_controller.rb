# frozen_string_literal: true

module Test
  class SessionsController < ApplicationController
    skip_before_action :load_current_user
    skip_before_action :set_current_request_context
    skip_before_action :verify_authenticity_token
    before_action :ensure_test_env

    def create
      user = User.find_by(id: params[:user_id])
      return render plain: "user not found", status: :not_found unless user

      session[:current_user_id] = user.id
      render plain: "signed in as #{user.login || user.id}", status: :ok
    end

    def destroy
      session.delete(:current_user_id)
      render plain: "signed out", status: :ok
    end

    private

    def ensure_test_env
      head :not_found unless Rails.env.test?
    end
  end
end
