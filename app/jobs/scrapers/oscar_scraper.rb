require_relative 'base'

module Jobs
  module Scrapers
    class OscarScraper < Base
      class JSONMatchError < Exception; end

      include Helpers::Scrapers::SpecialtiesHelper

      def self.perform(plan_id, url)
        plan = Plan.find(plan_id)
        if plan.nil?
          raise MissingSourceError.new("Missing Oscar in database. Are you sure the seed data is there?")
        end
        page_source = self.page_source_for_key(url)
        json_match = page_source.match(/fluxInitialState\s*=\s*(.+?);/)
        if json_match
          json = JSON.parse(json_match[1])
          csv_path = "#{ENV['STORAGE_DIRECTORY']}/oscar.csv"
          self.initialize_csv(csv_path)
          CSV.open(csv_path, 'a') do |csv|
            json["publicSearchInitialState"]["results"]["hits"].each do |provider_data|
              row = extract_provider(provider_data)
              if row
                row.unshift(plan.id)
                row.unshift(plan.payor.id)
                row.unshift(nil) # no directory ID
                csv << row
              end
            end
          end
        else
          raise JSONMatchError.new("Missing JSON for #{url}")
        end
      end

      def self.extract_provider provider_data
        row = []

        full_name = provider_data["name"]
        first_name = full_name.split(/\s+/)[0..-2].join(" ")
        last_name = full_name.split(/\s+/).last
        row << first_name
        row << last_name

        row << nil # no license

        address = provider_data["locations"].map do |location|
          result = location["address1"]
          if location["address2"]
            result += "\n#{location["address2"]}"
          end
          if location["city"] && location["state"] && location["zip"]
            result += "\n#{location["city"]}, #{location["state"]} #{location["zip"]}"
          end
          result
        end.join("\n\n")
        row << address

        phone = provider_data["locations"].map do |location|
          location["phone"]
        end.join("\n")
        row << phone

        row << nil # no specialties
        row << nil # no certificate_number
        row << nil # no certified

        profession = provider_data["primarySpecialty"].andand["name"]
        row << profession
      end
    end
  end
end
