module Jobs
  module Scrapers
    class Base
      def self.page_source_for_url(url)
        ssdb = SSDB.new url: "ssdb://#{ENV['SSDB_HOST']}:#{ENV['SSDB_PORT']}"
        unless ssdb.exists(url)
          raise MissingUpstreamDataError.new("No data upstream at SSDB server #{ENV['SSDB_HOST']} for URL: #{url}")
        end
        ssdb.get(url)
      end
    end
  end
end