require 'nokogiri'
require 'csv'

require_relative '../concerns/logged_job'

module Jobs
  module Scrapers
    class MissingSourceError < Exception; end

    class Base
      extend Jobs::Concerns::LoggedJob

      def self.initialize_csv(path, csv_fields)
        unless File.exists?(path)
          CSV.open(path, 'w+') do |csv|
            csv << csv_fields
          end
        end
      end
      
      def self.page_source_for_key(key)
        ssdb = SSDB.new url: "ssdb://#{ENV['SSDB_HOST']}:#{ENV['SSDB_PORT']}"
        unless ssdb.exists(key)
          raise MissingUpstreamDataError.new("No data upstream at SSDB server #{ENV['SSDB_HOST']} for key: #{key}")
        end
        ssdb.get(key)
      end

      def self.valid_license_type?(license_type)
        @license_type_blacklist ||= open("config/license_type_blacklist.txt").read.split("\n").map(&:strip)
        return !@license_type_blacklist.include?(license_type.to_s)
      end

      def self.strip_with_nbsp string
        return nil if string.nil?
        string.gsub(" ", " ").strip
      end
    end
  end
end