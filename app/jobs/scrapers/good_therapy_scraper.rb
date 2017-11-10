require_relative 'base'

module Jobs
  module Scrapers
    class GoodTherapyScraper < Base
      include Helpers::Scrapers::SpecialtiesHelper

      NAME_AND_LICENSE_REGEX = /\s((?:(?:[A-Z\-]\.|[A-Z\-]){2,})|Ph\.?D\.?|Psy\.?D\.?).*$/
      CSV_FIELDS = ['directory_id', 
                    'first_name', 
                    'last_name', 
                    'license', 
                    'address', 
                    'phone', 
                    'specialties', 
                    'license_number',
                    'website_url',
                    'minimum_fee',
                    'maximum_fee',
                    'sliding_scale',
                    'free_consultation',
                    'services',
                    'languages',
                    'modalities',
                    'works_with_ages',
                    'works_with_groups',
                    'accepted_payors']

      def self.perform(cache_key)
        directory = Directory.find_by(short_name: 'good-therapy')
        if directory.nil?
          raise MissingSourceError.new("Missing GoodTherapy Directory in database. Are you sure the seed data is there?")
        end
        doc = Nokogiri::HTML.parse(self.page_source_for_key(cache_key))
        csv_path = "#{ENV['STORAGE_DIRECTORY']}/good-therapy.csv"
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

        provider_name_and_license = strip_with_nbsp(doc.at_css('#profileTitle_id').content)
        provider_name_and_license.sub!(/^Dr.\s/, '')
        full_name = provider_name_and_license.sub(NAME_AND_LICENSE_REGEX, '')

        # since the comma is optional, it gets caught in the name for some records
        names = full_name.sub(/,$/, '').split(/\s+/).map(&:strip)

        provider_license_match = provider_name_and_license.match(NAME_AND_LICENSE_REGEX)
        provider_license = nil
        unless provider_license_match.nil?
          provider_license = provider_license_match.to_s.strip
        end

        row << names.first
        row << names[1..-1].join(" ")
        row << provider_license

        unless provider_license.nil? || valid_license_type?(provider_license)
          return nil
        end

        # multiple locations separated by double-line-breaksdd
        street_addresses = doc.css('div[itemprop="address"]').map do |div|
          # some addresses are missing critical data, so we'll do our best to dump what content
          # they have into an address field
          address = strip_with_nbsp(div.at_css('span[itemprop="streetAddress"]').andand.content)
          address2 = strip_with_nbsp(div.at_css('span[class*="address2"]').andand.content)
          city = strip_with_nbsp(div.at_css('span[itemprop="addressLocality"]').andand.content)
          state = strip_with_nbsp(div.at_css('span[itemprop="addressRegion"]').andand.content)
          zip = strip_with_nbsp(div.at_css('span[itemprop="postalCode"]').andand.content)

          # only include the final line if there's at least one city/state/zip
          address_last_line = (city || state || zip) ? "#{city}, #{state} #{zip}" : nil

          [address, address2, address_last_line].compact.join("\n")
        end
        street_addresses = street_addresses.join("\n\n")
        row << street_addresses

        phone = strip_with_nbsp(doc.at_css('.phone_profile_contact').content)
        row << phone

        specialties = doc.css('#issuesData li').map(&:content).map { |s| normalize_specialty(s) }.join(";")
        row << specialties

        primary_credential = strip_with_nbsp(doc.at_css('#licenceinfo1').andand.content)
        if primary_credential.andand.include?(" - ")
          license_number = primary_credential.split(" - ").last
          row << license_number
        else
          row << nil
        end

        website_url = doc.at_css('#edit_website').andand['href']
        row << website_url

        # fees
        fees = doc.at_css('p:contains("Fees:")')
        unless fees.nil?
          fees = strip_with_nbsp(fees.content.sub('Fees:', '').sub('$', '')) 
          if fees_match = fees.match(/\$?([0-9]{2,3})\s*(?:\-|to)\s*\$?([0-9]{2,3})\b/)
            minimum_fee = fees_match[1]
            maximum_fee = fees_match[2]
            row << minimum_fee
            row << maximum_fee
          elsif fees_match = fees.match(/(?:$|^)([0-9]+)\s/)
            minimum_fee = fees_match[1]
            row << minimum_fee
            row << nil # no maximum fee
          else
            row << nil # no minimum fee
            row << nil # no maximum fee
          end
        else
          row << nil # no minimum fee
          row << nil # no maximum fee
        end

        sliding_scale = !doc.at_css('#sliding_scale.green-checkmark').andand.text.strip.empty?
        free_consultation = !doc.at_css('#free_initial_consultation.green-checkmark').andand.text.strip.empty?
        row << sliding_scale
        row << free_consultation

        # practice details
        services = extract_list_items_for_selector(doc, '#servicesprovidedData li')
        row << services
        languages = extract_list_items_for_selector(doc, '#languagesData li')
        row << languages
        modalities = extract_list_items_for_selector(doc, '#editModels li')
        row << modalities
        works_with_ages = extract_list_items_for_selector(doc, '#agesData li')
        row << works_with_ages
        if doc.at_css('.groupsiworkwith')
          works_with_groups = strip_with_nbsp(doc.at_css('.groupsiworkwith').text).gsub(/,\s*/, ';')
          row << works_with_groups
        else
          row << nil
        end
        
        # insurance
        accepted_payors = doc.css('#billingData li').map(&:content).join(";")
        row << accepted_payors

        row
      end

      def self.extract_list_items_for_selector doc, selector
        strip_with_nbsp(doc.css(selector).map(&:content).join(";"))
      end

    end
  end
end