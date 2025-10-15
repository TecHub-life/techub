namespace :email do
  desc "Send a smoke test email via SystemMailer. Usage: rake 'email:smoke[to,message]'"
  task :smoke, [ :to, :message ] => :environment do |t, args|
    to = args[:to]
    message = args[:message]
    abort "Usage: rake 'email:smoke[to,message]'" if to.blank?

    mail = SystemMailer.with(to: to, message: message).smoke_test
    result = mail.deliver_now!
    puts({ id: result[:id], to: to }.to_json)
  end
end
