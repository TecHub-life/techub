# frozen_string_literal: true

require "open3"

ENV["RUBOCOP_CACHE_ROOT"] ||= "tmp/rubocop"
ENV["PARALLEL_WORKERS"] ||= "1"

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
  system("[ -d node_modules ]") || system("npm install")
end

run!("db:prepare") { system("bin/rails db:prepare") }
run!("db:setup:queue") { system("bin/rails db:setup:queue") }
run!("rubocop") { system("bin/rubocop") }
run!("prettier") { system("npm run --silent prettier:check") }
run!("test") { system("bin/rails test") }

puts "\nAll green!"
puts "techub.life"
