require 'resque'

options = { host:ENV['REDIS_HOST'], port: ENV['REDIS_PORT'] }
options[:password] = ENV['REDIS_PASS'] unless ENV['REDIS_PASS'].to_s.empty?
Resque.redis = Redis.new(options)
Resque.redis.namespace = "resque"