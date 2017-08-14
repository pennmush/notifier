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

get '/test_escape' do
  mush_escape("Hello(), %c! [ansi(h,test)]. https://github.com/onetwothree")
end

post '/' do
  payload = JSON.parse(params[:payload])
  return unless payload["repository"]["full_name"] == "pennmush/pennmush" # Don't send notifications unless this is the real deal.

  github_sender_name = payload["sender"]["login"]
  sender_name = mush_escape(settings.names.has_key?(github_sender_name) ? settings.names[github_sender_name] : github_sender_name)

  if payload["comment"]
    message = "[ansi(h,#{sender_name})] added a comment to issue ##{mush_escape(payload["issue"]["number"])} (#{mush_escape(payload["issue"]["title"])}). #{mush_escape(payload["comment"]["html_url"])}"
  elsif payload["issue"]
    return unless ["opened", "closed", "reopened"].include? payload["action"]
    message = "[ansi(h,#{sender_name})] #{mush_escape(payload["action"])} issue ##{mush_escape(payload["issue"]["number"])} (#{mush_escape(payload["issue"]["title"])}). #{mush_escape(payload["issue"]["html_url"])}"
  elsif payload["pull_request"]
    return unless ["opened", "closed", "reopened"].include? payload["action"]
    action = payload["pull_request"]["merged"] ? "merged" : payload["action"] # Merged PRs still have a 'closed' action, so need to look for merged key.
    message = "[ansi(h,#{sender_name})] #{mush_escape(action)} PR ##{mush_escape(payload["pull_request"]["number"])} (#{mush_escape(payload["pull_request"]["title"])}). #{mush_escape(payload["pull_request"]["html_url"])}"
  elsif payload["commits"]
    return unless payload["ref"] == "refs/heads/master" # We only want to notify on pushes to master, not to branches.
    message = "[ansi(h,#{sender_name})] pushed #{payload["commits"].count} commit#{payload["commits"].count == 1 ? '' : 's'} to master. #{mush_escape(payload["compare"])})]"
  else
    return 401 # We got an event we shouldn't have.
  end

  tn = Net::Telnet.new('Host' => settings.mush_host, 'Port' => settings.mush_port)
  tn.write "#{settings.mush_connect_string}\n"
  tn.write "#{settings.command_prefix} #{message}\n"
  tn.write "QUIT\n"
  tn.close

  return message
end

def mush_escape(str)
  str.to_s.gsub(/([\%\;\[\]\{\}\\\(\)\,\^\$])/, '%\1')
end
