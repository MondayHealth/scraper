require_relative 'base'

module Jobs
  module Scrapers
    class AetnaScraper < Base
      def self.perform(plan_id, url)
        plan = Plan.find(plan_id)
        doc = Nokogiri::HTML.parse(self.page_source_for_url(url))
        self.initialize_csv('aetna.csv')
        CSV.open('aetna.csv', 'a') do |csv|
          doc.css('#providersTable .result_location_top_public').each do |td|
            row = extract_doctor(td)
            row.unshift(plan.provider.id)
            row.unshift(plan_id)
            csv << row
          end
        end
      end

      def self.extract_doctor(td)
        # name and license is the first link in the cells
        doctor_name_and_license = td.at_css('.links').content

        # skip to element just before the address
        elem = td.at_css('.poi_detailsPage')
        elem = elem.next
        address = elem.content.gsub(/\s+/, ' ').strip

        # phone is after a <br> right after address and has text "Phone:"
        elem = elem.next while elem && !elem.content.include?("Phone")
        phone = elem.content.gsub(/\s+/, ' ').sub("Phone:", '').strip
        
        # specialties are right after <b>Specialties<b> beneath phone
        while elem && !elem.content.include?("Specialties")
          elem = elem.next
        end
        elem = elem.next
        specialties = elem.content.gsub(/\s+/, ' ').strip

        extract_info_for_row(doctor_name_and_license, address, phone, specialties)
      end

      def self.extract_info_for_row doctor_name_and_license, address, phone, specialties
        row = []
        names = doctor_name_and_license.split(", ")
        doctor_license = names.last
        doctor_first_name = names[1]
        doctor_last_name = names.first
        row << doctor_first_name
        row << doctor_last_name
        row << doctor_license
        row << address
        row << phone
        row << specialties.gsub("; ", ";")
        row
      end
    end
  end
end