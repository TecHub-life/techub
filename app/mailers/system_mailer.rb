class SystemMailer < ApplicationMailer
  def smoke_test
    @message = params[:message].presence || "TecHub email smoke test"
    mail(to: params[:to], subject: "TecHub email smoke test")
  end
end
