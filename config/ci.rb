# frozen_string_literal: true

require "open3"

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
