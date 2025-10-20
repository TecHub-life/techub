namespace :leaderboards do
  desc "Rebuild all leaderboards"
  task rebuild: :environment do
    Leaderboard::KINDS.each do |k|
      Leaderboard::WINDOWS.each do |w|
        result = Leaderboards::ComputeService.call(kind: k, window: w, as_of: Date.today)
        puts "#{k}/#{w}: #{result.success? ? 'ok' : 'fail'}"
      end
    end
  end

  desc "Capture leaderboard OG card"
  task :capture_og, [ :kind, :window ] => :environment do |_, args|
    kind = args[:kind] || "followers_gain_30d"
    window = args[:window] || "30d"
    result = Leaderboards::CaptureOgJob.perform_now(kind: kind, window: window)
    puts "capture: #{result.success? ? 'ok' : 'fail'}"
  end
end
