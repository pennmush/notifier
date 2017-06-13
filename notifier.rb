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
    message = "[ansi(h,lit(#{sender_name}))] added a comment to issue #[lit(#{payload["issue"]["number"]})] ([lit(#{payload["issue"]["title"]})]. [lit(#{payload["comment"]["html_url"]})]"
  elsif payload["issue"]
    return unless ["opened", "closed", "reopened"].include? payload["action"]
    message = "[ansi(h,lit(#{sender_name}))] [lit(#{payload["action"]})] issue #[lit(#{payload["issue"]["number"]})] ([lit(#{payload["issue"]["title"]})]). [lit(#{payload["issue"]["html_url"]})]"
  elsif payload["pull_request"]
    return unless ["opened", "closed", "reopened"].include? payload["action"]
    action = payload["pull_request"]["merged"] ? "merged" : payload["action"] # Merged PRs still have a 'closed' action, so need to look for merged key.
    message = "[ansi(h,lit(#{sender_name}))] [lit(#{action})] PR #[lit(#{payload["pull_request"]["number"]})] ([lit(#{payload["pull_request"]["title"]})]). [lit(#{payload["pull_request"]["html_url"]})]"
  elsif payload["commits"]
    return unless payload["ref"] == "refs/heads/master" # We only want to notify on pushes to master, not to branches.
    message = "[ansi(h,lit(#{sender_name}))] pushed [lit(#{payload["commits"].count})] commit#{payload["commits"].count == 1 ? '' : 's'} to master. [lit(#{payload["compare"]})]"
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
