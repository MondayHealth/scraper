require_relative 'base'

module Jobs
  module Scrapers
    class EmpireScraper < Base

      CSV_FIELDS = ['payor_id', 'accepted_plan_ids', 'first_name', 'last_name', 'license', 'address', 'phone', 'accepting_new_patients', 'specialties']

      def self.perform(plan_id, url)
        plan = Plan.find(plan_id)
        page_source = self.page_source_for_key(url)
        doc = Nokogiri::HTML.parse(page_source)
        csv_path = "#{ENV['STORAGE_DIRECTORY']}/empire.csv"
        self.initialize_csv(csv_path, CSV_FIELDS)
        CSV.open(csv_path, 'a') do |csv|
          doc.css("#results-list .result-item").each do |li|
            row = extract_provider(li)
            if row
              row.unshift(plan.id)
              row.unshift(plan.payor.id)
              csv << row
            end
          end
        end
      end

      def self.extract_provider li
        row = []

        provider_name_and_license = li.at_css("a[data-test^='provider-profile-link']").text
        names_and_licenses = provider_name_and_license.split(", ")

        first_name = names_and_licenses[1].strip
        row << first_name

        last_name = names_and_licenses.first.strip
        row << last_name
        
        licenses = names_and_licenses[2..-1].map(&:strip)
        row << licenses.join(", ")

        street_address = li.at_css('.address address .street-address').text
        street_address2 = li.at_css('.address address .extended-address').andand.text
        city = li.at_css('.address address .locality').text
        state = li.at_css('.address address .region').text
        zip = li.at_css('.address address .postal-code').text
        address = [street_address, street_address2, "#{city}, #{state} #{zip}"].compact.join("\n")
        row << address

        phone = li.at_css('div.phone-number a').text
        row << phone

        accepting_new_patients = li.at_css("div[data-test='anp-status']").andand.text.include?('Accepting new patients')
        row << accepting_new_patients

        specialties = li.at_css("span[data-test='displayed-specialties']").andand.text.andand.gsub(/,\s*/, ";")
        row << specialties

        row
      end
    end
  end
end

