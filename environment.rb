require_relative 'defaults'

require 'otr-activerecord'

OTR::ActiveRecord.configure_from_file! "config/database.yml"

Dir[File.join("app", "**/*.rb")].each do |file_path|
  require_relative file_path
end

Resque.redis = "#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}"
Resque.redis.namespace = "resque:scraper"