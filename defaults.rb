ENV['RACK_ENV'] ||= 'development'
ENV['REDIS_HOST'] ||= "localhost"
ENV['REDIS_PORT'] ||= "6379"
ENV['REDIS_PASS'] ||= ""
ENV['SSDB_HOST'] ||= "localhost"
ENV['SSDB_PORT'] ||= "8888"
ENV['SSDB_PASS'] ||= ""
ENV['DATABASE_URL'] ||= 'postgres://localhost/crawler'