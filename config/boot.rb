ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

if ENV["RAILS_ENV"] == "test"
  ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"] ||= "0" * 32
  ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"] ||= "1" * 32
  ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"] ||= "2" * 32
end
