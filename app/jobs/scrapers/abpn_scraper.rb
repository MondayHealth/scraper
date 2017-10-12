require_relative 'base'

module Jobs
  module Scrapers
    class AbpnScraper < Base
      include Helpers::Scrapers::SpecialtiesHelper

      NAME_AND_LICENSE_REGEX = /\s((?:,\s)?((?:(?:[A-Z]\.|[A-Z]){2,})|Ph\.D\.))+/
      CERTIFICATE_NUMBER_REGEXP = /Certificate No\. ([0-9])+/

      def self.perform(cache_key)
        directory = Directory.find_by(short_name: 'abpn')
        if directory.nil?
          raise MissingSourceError.new("Missing ABPN Directory in database. Are you sure the seed data is there?")
        end
        doc = Nokogiri::HTML.parse(self.page_source_for_key(cache_key))
        csv_path = "#{ENV['STORAGE_DIRECTORY']}/abpn.csv"
        self.initialize_csv(csv_path)
        CSV.open(csv_path, 'a') do |csv|
          doc.css('#body tr:has(td.body)').each do |tr|
            row = extract_provider(tr)
            if row
              row.unshift(nil) # no plan ID
              row.unshift(nil) # no payor ID
              row.unshift(directory.id)
              csv << row
            end
          end
        end
      end

      def self.strip_with_nbsp string
        string.gsub(" ", " ").strip
      end

      def self.extract_provider tr
        # name and license is the first link in the cells
        provider_name_and_license = strip_with_nbsp(tr.at_css('td:nth(1)').content)
        city = strip_with_nbsp(tr.at_css('td:nth(2)').content)
        state = strip_with_nbsp(tr.at_css('td:nth(3)').content)
        specialties_and_certificate_number = strip_with_nbsp(tr.at_css('td:nth(4)').content)
        certification_status = strip_with_nbsp(tr.at_css('td:nth(6)').content)
        extract_info_for_row(provider_name_and_license, city, state, specialties_and_certificate_number, certification_status)
      end

      def self.extract_info_for_row provider_name_and_license, city, state, specialties_and_certificate_number, certification_status
        row = []
        full_name = provider_name_and_license.sub(NAME_AND_LICENSE_REGEX, '')
        names = full_name.split(",").map(&:strip)
        provider_license_match = provider_name_and_license.match(NAME_AND_LICENSE_REGEX)
        provider_license = nil
        unless provider_license_match.nil?
          provider_license = provider_license_match[1].strip
        end

        unless provider_license.nil? || valid_license_type?(provider_license)
          return nil
        end

        address = "#{city.strip}, #{state.strip}"

        certificate_number = nil
        certificate_number_match = specialties_and_certificate_number.match(CERTIFICATE_NUMBER_REGEXP)
        if certificate_number_match
          certificate_number = certificate_number_match[1]
        end

        # Specialties have asterisks and the certificate number after them in the original data
        specialties = specialties_and_certificate_number.sub(CERTIFICATE_NUMBER_REGEXP, '').strip.gsub('*', '')
        # we only get one specialty from ABPN, so no need to split
        specialties = normalize_specialty(specialties)

        is_certified = certification_status.match("Not Certified").nil?

        provider_first_name = names[1]
        provider_last_name = names.first
        row << provider_first_name
        row << provider_last_name
        row << provider_license
        row << address
        row << nil # no phone records to add here
        row << specialties
        row << certificate_number
        row << is_certified
        row
      end
    end
  end
end
