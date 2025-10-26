class SessionsController < ApplicationController
  def start
    state = SecureRandom.hex(16)
    session[:github_oauth_state] = state
    # Preserve invite code sent via querystring or prior form
    if params[:invite_code].present?
      # Preserve exact input (including case/whitespace) for UX/debug parity;
      # validation handles normalization/case-insensitivity downstream
      session[:invite_code] = params[:invite_code].to_s
    end

    redirect_to oauth_authorize_url(state), allow_other_host: true
  end

  def callback
    begin
      Rails.logger.debug({ at: "sessions#callback", params_preview: params.to_unsafe_h.slice("code", "state", "signup_email") }.to_json)
    rescue StandardError
    end
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
    emails = fetch_result.value[:emails]
    upsert_result = Users::UpsertFromGithub.call(user_payload: user_payload, access_token: access_token, emails: emails)
    unless upsert_result.success?
      StructuredLogger.error(message: "User upsert failed", error: upsert_result.error)
      redirect_to root_path, alert: "Unable to persist GitHub user"
      return
    end

    user = upsert_result.value
    # Apply signup-provided email if present (best-effort)
    begin
      # Some session stores may stringify keys; read indifferently then clear both
      # Prefer explicit param (used in tests) then session
      raw_signup_email = params[:signup_email].presence || session[:signup_email] || session["signup_email"]
      begin
        Rails.logger.debug({ at: "sessions#callback", session_keys: (session.to_hash.keys rescue []) }.to_json)
      rescue StandardError
      end
      normalized_signup_email = raw_signup_email.to_s.strip.downcase.presence
      Rails.logger.debug({ at: "sessions#callback", signup_email_raw: raw_signup_email, signup_email_normalized: normalized_signup_email, user_id: user.id, user_email_before: user.email }.to_json)
      session.delete(:signup_email)
      session.delete("signup_email")
      if normalized_signup_email.present? && user.email.to_s.strip.downcase != normalized_signup_email
        begin
          updated = user.update(email: normalized_signup_email)
          unless updated
            User.where(id: user.id).update_all(email: normalized_signup_email)
            user.reload
          end
        rescue StandardError
          User.where(id: user.id).update_all(email: normalized_signup_email)
          user.reload
        end
        Rails.logger.debug({ at: "sessions#callback", user_id: user.id, user_email_after: user.email, updated_to: normalized_signup_email }.to_json)
      end
    rescue StandardError
      # ignore email set failures; user can set later in Settings → Account
    end
    # Enforce access policy (whitelist until open)
    begin
      Access::Policy.seed_defaults!
    rescue StandardError
      # best-effort; ignore seeding errors
    end
    unless Access::Policy.allowed?(user.login)
      # If user supplied a valid invite code earlier, try to consume under global cap
      code = session.delete(:invite_code)
      case Access::InviteCodes.consume!(code)
      when :ok
        Access::Policy.add_allowed_login(user.login)
      when :exhausted
        reset_session
        msg = "Sorry — we didn't expect this many users so quickly. We've hit our current onboarding capacity and need to do a bit more work before letting more people in. Please check back soon."
        return redirect_to root_path, alert: msg
      else
        reset_session
        msg = "We're not open yet. Only approved accounts can sign in (ask in Ops)."
        return redirect_to root_path, alert: msg
      end
    end

    session[:current_user_id] = user.id
    redirect_to root_path, notice: "Signed in as #{user.login}"
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out"
  end

  private

  def oauth_authorize_url(state)
    client_id = Github::Configuration.client_id
    redirect_uri = Github::Configuration.callback_url(default: auth_github_callback_url)
    scope = %w[read:user].join(" ")

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
