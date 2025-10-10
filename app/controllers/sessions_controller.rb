class SessionsController < ApplicationController
  def start
    state = SecureRandom.hex(16)
    session[:github_oauth_state] = state

    redirect_to oauth_authorize_url(state), allow_other_host: true
  end

  def callback
    if params[:code].blank?
      redirect_to root_path, alert: "Missing code from GitHub"
      return
    end

    if session[:github_oauth_state].blank? || session[:github_oauth_state] != params[:state]
      session.delete(:github_oauth_state)
      redirect_to root_path, alert: "GitHub login state mismatch"
      return
    end

    session.delete(:github_oauth_state)

    token_result = Github::UserOauthService.call(code: params[:code], redirect_uri: Github::Configuration.callback_url(default: auth_github_callback_url))
    unless token_result.success?
      StructuredLogger.error(message: "GitHub OAuth failed", error: token_result.error)
      redirect_to root_path, alert: "GitHub login failed"
      return
    end

    access_token = token_result.value[:access_token]

    fetch_result = Github::FetchAuthenticatedUser.call(access_token: access_token)
    unless fetch_result.success?
      StructuredLogger.error(message: "GitHub user fetch failed", error: fetch_result.error)
      redirect_to root_path, alert: "Failed to fetch GitHub profile"
      return
    end

    user_payload = fetch_result.value[:user]
    upsert_result = Users::UpsertFromGithub.call(user_payload: user_payload, access_token: access_token)
    unless upsert_result.success?
      StructuredLogger.error(message: "User upsert failed", error: upsert_result.error)
      redirect_to root_path, alert: "Unable to persist GitHub user"
      return
    end

    session[:current_user_id] = upsert_result.value.id
    redirect_to root_path, notice: "Signed in as #{upsert_result.value.login}"
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out"
  end

  private

  def oauth_authorize_url(state)
    client_id = Github::Configuration.client_id
    redirect_uri = Github::Configuration.callback_url(default: auth_github_callback_url)
    scope = %w[read:user user:email].join(" ")

    URI::HTTPS.build(
      host: "github.com",
      path: "/login/oauth/authorize",
      query: {
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: scope,
        state: state
      }.to_query
    ).to_s
  end
end
