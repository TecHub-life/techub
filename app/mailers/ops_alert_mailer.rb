require "socket"

class OpsAlertMailer < ApplicationMailer
  def job_failed
    @profile = params[:profile]
    @job = params[:job]
    @error_message = params[:error_message]
    @metadata = params[:metadata]
    @duration_ms = params[:duration_ms]

    # Runtime context for the template
    @rails_env = Rails.env
    @hostname = (Socket.gethostname rescue nil)
    @pid = Process.pid
    @app_host = ENV["APP_HOST"].to_s.presence
    @app_revision = ENV["APP_REVISION"].to_s.presence

    to = params[:to]
    if @error_message.present?
      subject = "[TecHub][#{Rails.env}] Job failed: #{@job} for @#{@profile&.login}"
    else
      subject = "[TecHub][#{Rails.env}] Job report: #{@job} for @#{@profile&.login}"
    end

    mail(to: to, subject: subject)
  end
end
