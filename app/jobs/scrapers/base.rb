require 'nokogiri'
require 'csv'

require_relative '../concerns/logged_job'

module Jobs
  module Scrapers
    CSV_FIELDS = ['directory_id', 'payor_id', 'accepted_plan_ids', 'first_name', 'last_name', 'license', 'address', 'phone', 'specialties', 'certificate_number', 'certified']

    class MissingSourceError < Exception; end

    class Base
      extend Jobs::Concerns::LoggedJob

      def self.initialize_csv(path)
        unless File.exists?(path)
          CSV.open(path, 'w+') do |csv|
            csv << CSV_FIELDS
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
    end
  end
end