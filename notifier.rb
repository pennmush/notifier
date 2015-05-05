require 'sinatra'
require 'json'
require 'net/telnet'
require 'yaml'

set :mush_host, ENV['NOTIFIER_HOST']
set :mush_port, ENV['NOTIFIER_PORT']
set :mush_connect_string, ENV['NOTIFIER_CONNECT_STRING']
set :command_prefix, ENV['NOTIFIER_COMMAND_PREFIX']
set :names, YAML.load_file('names.yml')

get '/' do
  "The Notifier is set up and running properly and will connect to #{settings.mush_host} #{settings.mush_port}. See https://github.com/pennmush/notifier for more information."
end

post '/' do
  payload = JSON.parse(params[:payload])
  return unless payload["repository"]["full_name"] == "pennmush/pennmush" # Don't send notifications unless this is the real deal.

  github_sender_name = payload["sender"]["login"]
  sender_name = settings.names.has_key?(github_sender_name) ? settings.names[github_sender_name] : github_sender_name

  if payload["comment"]
    message = "#{sender_name} added a comment to issue ##{payload["issue"]["number"]} (#{payload["issue"]["title"]}). #{payload["comment"]["url"]}"
  elsif payload["issue"]
    return unless ["opened", "closed", "reopened"].include? payload["action"]
    message = "#{sender_name} #{payload["action"]} issue ##{payload["issue"]["number"]} (#{payload["issue"]["title"]}). #{payload["issue"]["html_url"]}"
  elsif payload["pull_request"]
    return unless ["opened", "closed", "reopened"].include? payload["action"]
    message = "#{sender_name} #{payload["action"]} PR ##{payload["pull_request"]["number"]} (#{payload["pull_request"]["title"]}). #{payload["pull_request"]["html_url"]}"
  elsif payload["commits"]
    return unless payload["ref"] == "refs/heads/master" # We only want to notify on pushes to master, not to branches.
    message = "#{sender_name} pushed #{payload["commits"].count} commit#{payload["commits"].count == 1 ? '' : 's'} to master. #{payload["compare"]}"
  else
    return 401 # We got an event we shouldn't have.
  end

  return message
  tn = Net::Telnet.new('Host' => settings.mush_host, 'Port' => settings.mush_port)
  tn.write settings.mush_connect_string + "\n"
  messages.each do |msg|
    tn.write "#{msg}\n"
  end
  tn.write "QUIT\n"
  tn.close

  return message
end
