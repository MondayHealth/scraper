require_relative 'base'

module Jobs
  module Scrapers
    class OscarScraper < Base
      class JSONMatchError < Exception; end

      include Helpers::Scrapers::SpecialtiesHelper

      HONORIFICS_FOR_PROFESSIONS = {
        "Marriage and Family Therapist": "LMFT",
        "Mental Health Counselor": "LMHC",
        "Psychiatrist specializing in Pediatrics": "MD",
        "Psychiatrist specializing in addiction problems": "MD",
        "Psychiatrist specializing in geriatrics": "MD",
        "Psychologist": "PhD",
        "Social Worker": "LCSW"
      }

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

        profession = provider_data["primarySpecialty"].andand["name"]
        licenses = profession.split(/,\s/).map { |p| HONORIFICS_FOR_PROFESSIONS[p.to_sym] }.compact.sort.uniq
        row << licenses.join(", ")

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
      end

    end
  end
end
