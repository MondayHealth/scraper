require_relative 'defaults'

require 'core'
require 'otr-activerecord'
require 'ssdb'

OTR::ActiveRecord.configure_from_file! "config/database.yml"

Dir[File.join("config/initializers", "*.rb")].each do |file_path|
  require_relative file_path
end

Dir[File.join("app", "**/*.rb")].each do |file_path|
  require_relative file_path
end