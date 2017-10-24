require_relative 'base'

module Jobs
  module Scrapers
    class CignaScraper < Base

      CSV_FIELDS = ['payor_id', 'accepted_plan_ids', 'first_name', 'last_name', 'license', 'address', 'phone', 'accepting_new_patients']

      NAME_AND_LICENSE_REGEX = /\s((?:,\s)?[A-Z]{2,})+/

      def self.perform(plan_id, url)
        plan = Plan.find(plan_id)
        page_source = self.page_source_for_key(url)
        doc = Nokogiri::HTML.parse(page_source)
        csv_path = "#{ENV['STORAGE_DIRECTORY']}/cigna.csv"
        self.initialize_csv(csv_path, CSV_FIELDS)
        CSV.open(csv_path, 'a') do |csv|
          doc.css("tr").each do |tr|
            row = extract_provider(tr)
            if row
              row.unshift(plan.id)
              row.unshift(plan.payor.id)
              csv << row
            end
          end
        end

      end

      def self.extract_provider tr
        row = []

        full_name_and_license = tr.at_css('.address-header a').text.strip
        full_name = full_name_and_license.sub(NAME_AND_LICENSE_REGEX, '').sub(/,$/, '')
        first_name = full_name.split(/,\s*/).last
        row << first_name

        last_name = full_name.split(/,\s*/).first
        row << last_name

        provider_license_match = full_name_and_license.match(NAME_AND_LICENSE_REGEX)
        if provider_license_match
          row << provider_license_match.to_s.strip
        else
          row << nil
        end

        # they use a non-breaking space to separate the lines of the address
        address = tr.at_css(".pipe-links li:nth-child(2)").text.strip.gsub(" ", "\n")
        row << address
        
        phone = tr.at_css(".pipe-links li:first-child").text.strip
        row << phone

        accepting_new_patients = !tr.at_css(".icon.success").nil?
        row << accepting_new_patients
      end
    end
  end
end