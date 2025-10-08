#!/usr/bin/env ruby
# Usage: ruby script/sa_json_to_yaml.rb path/to/key.json
# Prints a YAML block suitable for credentials: application_credentials_json

require "json"

path = ARGV[0] or abort "Usage: ruby script/sa_json_to_yaml.rb path/to/key.json"
json = JSON.parse(File.read(path))
compact = JSON.generate(json)

puts <<~YAML
application_credentials_json: |
  #{compact}
YAML
