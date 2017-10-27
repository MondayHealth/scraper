require_relative 'base'

module Jobs
  module Scrapers
    class CareConnectScraper < Base
      CSV_FIELDS = ['payor_id', 'accepted_plan_ids', 'first_name', 'last_name', 'license', 'address', 'phone', 'specialties', 'group_affiliation']

      def self.perform(plan_id, url)
        plan = Plan.find(plan_id)
        page_source = self.page_source_for_key(url)
        json = JSON.parse(page_source)
        csv_path = "#{ENV['STORAGE_DIRECTORY']}/careconnect.csv"
        self.initialize_csv(csv_path, CSV_FIELDS)
        CSV.open(csv_path, 'a') do |csv|
          json["d"]["Providers"].each do |provider_data|
            row = extract_provider(provider_data)
            if row
              row.unshift(plan.id)
              row.unshift(plan.payor.id)
              csv << row
            end
          end
        end
      end

      def self.extract_provider provider_data
        row = []

        first_name = provider_data["PersonalInfo"]["FirstName"]
        middle_name = provider_data["PersonalInfo"]["MiddleName"]

        row << "#{first_name} #{middle_name}".strip

        last_name = provider_data["PersonalInfo"]["LastName"]
        row << last_name

        provider_license = provider_data["PersonalInfo"]["Degree"]
        row << provider_license

        address_data = provider_data["Location"]["Address"]
        address = [address_data["Address"], 
                   address_data["Address2"], 
                   "#{address_data["City"]}, #{address_data["State"]} #{address_data["Zipcode"]}"].compact.join("\n")
        row << address

        phone = nil
        if provider_data["Location"]["HasPhoneNumbers"]
          phone = provider_data["Location"]["PhoneNumbers"].map do |phone_data|
            if phone_data["PhoneType"].downcase == 'phone'
              phone_data["PhoneNumber"]
            else
              nil
            end
          end.compact.join("\n")
        end
        row << phone

        specialties = nil
        if provider_data["HasSpecialties"]
          specialties = provider_data["Specialties"].map do |specialty|
            specialty["Name"]
          end.join("; ")
        end
        row << specialties
        
        group_affiliations = nil
        if provider_data["HasGroupAffiliations"]
          group_affiliations = provider_data["GroupAffiliations"].map do |group|
            group["Name"]
          end.join("; ")
        end
        row << group_affiliations

      end
    end
  end
end