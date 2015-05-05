require 'net/http'
require 'uri'

base_url = "http://localhost:9292/" # change as needed.

# Sample payload, from the Github documentation.
test_file = ARGV[0] || "push"

json = File.read("tests/#{test_file}.json")
puts "Running test with #{test_file}.json."
res = Net::HTTP.post_form(URI.parse(base_url), {'payload' => json})
puts "Status: #{res.code}"
puts "Body:"
puts res.body
