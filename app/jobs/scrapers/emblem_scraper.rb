require_relative 'base'

module Jobs
  module Scrapers
    class EmblemScraper < Base

      CSV_FIELDS = ['payor_id', 'accepted_plan_ids', 'first_name', 'last_name', 'license', 'address', 'phone']

      def self.perform(plan_id, url)
        plan = Plan.find(plan_id)
        page_source = self.page_source_for_key(url)
        # output is full of non-breaking spaces, so strip them up-front
        doc = Nokogiri::HTML.parse(page_source.gsub(/&nbsp;/, " "))
        csv_path = "#{ENV['STORAGE_DIRECTORY']}/emblem.csv"
        self.initialize_csv(csv_path, CSV_FIELDS)
        CSV.open(csv_path, 'a') do |csv|
          doc.css("#searchResultsTable tbody tr").each do |tr|
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

        name_link = tr.at_css("a[href*='/referralconnect/providerDetails.do']")
        full_name_and_license = name_link.text
        first_name_and_license = full_name_and_license.split(/,\s*/).last
        first_name = first_name_and_license.split(/\s+/)[0...-1].join(" ").strip
        row << first_name

        last_name = full_name_and_license.split(/,\s*/).first.strip
        row << last_name

        provider_license = first_name_and_license.split(/\s+/).last.strip
        row << provider_license

        address_elem = tr.at_css("td:nth-child(4)")
        phone = address_elem.at_css("strong").text.strip
        address_elem.css("strong").remove
        address = address_elem.inner_html.gsub(/<br\/?>/i, "\n").strip

        row << address
        row << phone

        row
      end
    end
  end
end