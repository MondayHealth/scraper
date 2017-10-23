require_relative 'base'

module Jobs
  module Scrapers
    class OxfordScraper < Base

      CSV_FIELDS = ['payor_id', 'accepted_plan_ids', 'first_name', 'last_name', 'license', 'address', 'phone']

      def self.perform(plan_id, url)
        plan = Plan.find(plan_id)
        page_source = self.page_source_for_key(url)
        json = JSON.parse(page_source)
        csv_path = "#{ENV['STORAGE_DIRECTORY']}/oxford.csv"
        self.initialize_csv(csv_path, CSV_FIELDS)
        CSV.open(csv_path, 'a') do |csv|
          json["results"].each do |provider_data|
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
        row = []

        first_name = provider_data["name"].andand["first"]
        if middle_initial = provider_data["name"].andand["middle"]
          first_name += " #{middle_initial}."
        end
        row << first_name

        last_name = provider_data["name"].andand["last"]
        row << last_name

        degree = provider_data["name"].andand["degree"]
        row << degree

        address = provider_data["locations"].map do |location_data|
          if location_data["address"]
            "#{location_data["address"]["street1"]}\n#{location_data["address"]["city"]}, #{location_data["address"]["state"]} #{location_data["address"]["zipCode"]}"
          end
        end.compact.join("\n\n")
        row << address

        phone = provider_data["locations"].map do |location_data|
          if location_data["phones"]
            phone_data = location_data["phones"].find { |phone| phone["phoneType"] == "phone" }
            # some records have phoneType as "unknown"; if we don't find one explicitly marked
            # as "phone", fall back to any number not marked as "fax" instead
            phone_data ||= location_data["phones"].find { |phone| phone["phoneType"] != "fax" }
            phone_data.andand["number"]
          end
        end.compact.join("\n")
        row << phone
      end
    end
  end
end
