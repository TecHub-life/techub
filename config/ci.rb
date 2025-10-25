# frozen_string_literal: true

require "open3"

ENV["RUBOCOP_CACHE_ROOT"] ||= "tmp/rubocop"
ENV["PARALLEL_WORKERS"] ||= "1"
# Disable parallel tests in CI/sandboxed environments to avoid DRb socket issues
ENV["DISABLE_PARALLEL_TESTS"] ||= "1"

def banner
  # rubocop:disable Layout/TrailingWhitespace
  <<~'BANNER'

  _____                   _  _            _      
 |_   _|   ___     __    | || |   _  _   | |__   
   | |    / -_)   / _|   | __ |  | +| |  | '_ \  
  _|_|_   \___|   \__|_  |_||_|   \_,_|  |_.__/  
_|"""""|_|"""""|_|"""""|_|"""""|_|"""""|_|"""""| 
"`-0-0-'"`-0-0-'"`-0-0-'"`-0-0-'"`-0-0-'"`-0-0-' 

techub.life • AI-powered GitHub trading cards
  BANNER
  # rubocop:enable Layout/TrailingWhitespace
end

puts banner

def run!(label)
  puts "\n== #{label} =="
  success = yield
  return if success

  puts "#{label} failed"
  exit(1)
end

run!("bundle install") do
  system("bundle check") || system("bundle install")
end

run!("npm install") do
  next true if system("[ -d node_modules ]")

  cmd = if File.exist?("package-lock.json")
    "npm ci --no-fund --no-audit --loglevel=error"
  else
    "npm install --no-fund --no-audit --loglevel=error"
  end

  system(cmd)
end

run!("db:prepare") { system("bin/rails db:prepare") }
run!("db:setup:queue") { system("bin/rails db:setup:queue") }
run!("rubocop") { system("bin/rubocop -A && bin/rubocop") }
run!("prettier") { system("npm run --silent prettier:check") }
# Use bundle exec to avoid bin/brakeman's --ensure-latest in CI sandboxes
run!("brakeman") { system("bundle exec brakeman -q -w2 --no-exit-on-warn --no-pager") }
puts <<~MSG

  Note: If Brakeman reported "Obsolete Ignore Entries", clean them locally:
    bundle exec brakeman -I --no-pager
  Then choose to remove obsolete entries and commit config/brakeman.ignore.

  If CI runners are low on disk, consider purging Docker caches:
    ./bin/docker-purge
  This removes unused images/containers/volumes and build cache.

  To run production-like tests locally with Docker Compose:
    RAILS_MASTER_KEY=$(cat config/master.key) docker compose up --build -d
    docker compose exec -T web bin/rails test

  To inspect Docker disk usage locally:
    docker system df

MSG
run!("test") { system("bin/rails test") }

# Optional: display Docker disk usage in CI environments that have Docker
if system("command -v docker >/dev/null")
  puts "\nDocker disk usage (for awareness):"
  system("docker system df || true")
end

# Optional Docker build + smoke test
if ENV["CI_BUILD_DOCKER"] == "1"
  run!("docker:build") do
    system("command -v docker >/dev/null") && system("docker build -t techub:ci .")
  end
  run!("docker:smoke") do
    system("docker run --rm --entrypoint ./bin/rails techub:ci --version")
  end
end

puts "\nAll green!"
puts "techub.life"
