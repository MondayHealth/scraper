require_relative 'base'

module Jobs
  module Scrapers
    class AetnaScraper < Base
      include Helpers::Scrapers::SpecialtiesHelper

      def self.perform(plan_id, url)
        STDOUT.write("Performing #{AetnaScraper} from #{__FILE__}")

        plan = Plan.find(plan_id)
        doc = Nokogiri::HTML.parse(self.page_source_for_url(url))
        csv_path = "#{ENV['STORAGE_DIRECTORY']}/aetna.csv"
        self.initialize_csv(csv_path)
        CSV.open(csv_path, 'a') do |csv|
          doc.css('#providersTable .result_location_top_public').each do |td|
            row = extract_doctor(td)
            if row
              row.unshift(plan_id)
              row.unshift(plan.payor.id)
              csv << row
            end
          end
        end
      end

      def self.extract_doctor(td)
        # In rare cases some rows have corrupt data, and the names aren't linked in a consistent
        # way for us to scrape. We skip them here so they don't bring down the job.
        return nil if td.at_css('.links').nil?

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
        specialties = specialties.split(/;\s*/).map { |s| normalize_specialty(s)}.join(';')

        extract_info_for_row(doctor_name_and_license, address, phone, specialties)
      end

      def self.extract_info_for_row doctor_name_and_license, address, phone, specialties
        row = []
        names = doctor_name_and_license.split(", ")
        doctor_license = names.last
        unless valid_license_type?(doctor_license)
          return nil
        end
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