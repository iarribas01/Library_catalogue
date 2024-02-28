require './library_catalogue'
require 'rack/unreloader'
Unreloader = Rack::Unreloader.new{Sinatra::Application}
Unreloader.require './library_catalogue.rb'
Unreloader.require './lib/database_persistence.rb'


require 'logger'
Logger.class_eval { alias :write :'<<' }
logger = ::Logger.new(::File.new("log/app.log","a+"))

configure do
    use Rack::CommonLogger, logger
end

run Unreloader