require_relative 'base'

module Jobs
  module Scrapers
    class UnitedScraper < Base

      CSV_FIELDS = ['payor_id', 'accepted_plan_ids', 'first_name', 'last_name', 'license', 'address', 'phone', 'accepting_new_patients']

      def self.perform(plan_id, url)
        plan = Plan.find(plan_id)
        if plan.nil?
          raise MissingSourceError.new("Missing United in database. Are you sure the seed data is there?")
        end
        page_source = self.page_source_for_key(url)
        json = JSON.parse(page_source)
        csv_path = "#{ENV['STORAGE_DIRECTORY']}/united.csv"
        self.initialize_csv(csv_path, CSV_FIELDS)
        CSV.open(csv_path, 'a') do |csv|
          json["clinicianList"].each do |provider_data|
            row = extract_provider(plan, provider_data)
            if row
              row.unshift(plan.id)
              row.unshift(plan.payor.id)
              csv << row
            end
          end
        end
      end

      def self.extract_provider plan, provider_data
        case plan.name
        when /Medicaid/
          return nil if provider_data["hasMedicaid"] != "YES"
        when /Medicare/
          return nil if provider_data["hasMedicare"] != "YES"
        end

        row = []

        first_name = provider_data["firstName"]
        row << first_name

        last_name = provider_data["lastName"]
        row << last_name
        
        licenses = provider_data["providerTypeList"]
        row << licenses.join(", ")

        address = "#{provider_data["street"]}\n#{provider_data["city"]}, #{provider_data["state"]} #{provider_data["zip"]}"
        row << address

        phone = provider_data["phone"]
        row << phone

        accepting_new_patients = provider_data["acceptingNewPatients"]
        row << accepting_new_patients
      end
    end
  end
end
