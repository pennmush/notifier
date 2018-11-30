# Just a simple sanity check test.

ENV['RACK_ENV'] = 'test'

require './notifier'
require 'test/unit'
require 'rack/test'

class HelloWorldTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_it_says_hello_world
    get '/'
    assert last_response.ok?
    assert last_response.body.include?('Notifier is set up and running properly')
  end
end
