class ProfilePipelineMailer < ApplicationMailer
  def completed
    @user = params[:user]
    @profile = params[:profile]
    mail(to: @user.email, subject: "Your TecHub card is ready for @#{@profile.login}")
  end

  def failed
    @user = params[:user]
    @profile = params[:profile]
    @error_message = params[:error_message]
    mail(to: @user.email, subject: "TecHub card failed for @#{@profile.login}")
  end
end
