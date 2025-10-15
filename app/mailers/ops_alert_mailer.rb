class OpsAlertMailer < ApplicationMailer
  def job_failed
    @profile = params[:profile]
    @job = params[:job]
    @error_message = params[:error_message]
    @metadata = params[:metadata]
    @duration_ms = params[:duration_ms]

    to = params[:to]
    subject = "[TecHub] Job failed: #{@job} for @#{@profile&.login}"

    mail(to: to, subject: subject)
  end
end
