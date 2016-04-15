require 'webrick'

# Set up ActiveRecord stuff

require_relative './active_record_lite/associatable.rb'
require_relative './active_record_lite/db_connection.rb' # use DBConnection.execute freely here.
require_relative './active_record_lite/mass_object.rb'
require_relative './active_record_lite/searchable.rb'
require_relative './active_record_lite/sql_object_base.rb'
require 'active_support/inflector'

Dir.entries("./models").each do |model|
  next if [".",".."].include? model
  require "./models/#{model}"
end

cats_db_file_name =
  File.expand_path(File.join(File.dirname(__FILE__), "../rails_lite/db/cats.db"))

DBConnection.open(cats_db_file_name)


server = WEBrick::HTTPServer.new :Port => 8000

trap 'INT' do server.shutdown end

server.mount_proc '/' do |request, response|
  load "./lib/router.rb"

  body = respond(request, response)
end

server.start