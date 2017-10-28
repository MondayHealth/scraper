require_relative 'base'

module Jobs
  module Scrapers
    class PsychologyTodayScraper < Base
      include Helpers::Scrapers::SpecialtiesHelper

      CSV_FIELDS = ['directory_id', 'first_name', 'last_name', 'license', 'address', 'phone', 'website_url']

      def self.perform(cache_key)
        directory = Directory.find_by(short_name: 'psych-today')
        if directory.nil?
          raise MissingSourceError.new("Missing PsychologyToday Directory in database. Are you sure the seed data is there?")
        end
        doc = Nokogiri::HTML.parse(self.page_source_for_key(cache_key))
        csv_path = "#{ENV['STORAGE_DIRECTORY']}/psychologytoday.csv"
        self.initialize_csv(csv_path, CSV_FIELDS)
        CSV.open(csv_path, 'a') do |csv|
          row = extract_provider(doc)
          if row
            row.unshift(directory.id)
            csv << row
          end
        end
      end

      def self.extract_provider doc
        row = []

        full_name = strip_with_nbsp(doc.at_css('h1[itemprop="name"]').text.gsub(/\s+/, " "))
        first_name = full_name.split(/\s+/)[0...-1].join(" ")
        row << first_name
        
        last_name = full_name.split(/\s+/).last
        row << last_name

        provider_license = strip_with_nbsp(doc.at_css('.profile-title').text.strip.gsub(/\s+/, " "))
        row << provider_license

        streetAddress = strip_with_nbsp(doc.at_css('.profile-address span[itemprop="streetAddress"]').inner_html.gsub(/<br\/?>/, "\n"))
        city = strip_with_nbsp(doc.at_css('.profile-address span[itemprop="addressLocality"]').text)
        state = strip_with_nbsp(doc.at_css('.profile-address span[itemprop="addressRegion"]').text)
        zip = strip_with_nbsp(doc.at_css('.profile-address span[itemprop="postalcode"]').text)
        address = [streetAddress, "#{city}, #{state} #{zip}"].join("\n")
        row << address

        phone = strip_with_nbsp(doc.at_css('.profile-address a[data-event-label="Address1_PhoneLink"]').text)
        row << phone

        specialties = doc.css('.spec-list ul li').map(&:text).map { |s| normalize_specialty(s) }.join(";")
        row << specialties

        row
      end
    end
  end
end